    #!/bin/bash
    # Filename: create_installer.sh

    # Parameters
    goplay_binary=./bin/goplay
    goplayer_binary=./bin/goplayer
    service_file=./etc/goplay.service
    install_path="~/.local/bin"
    systemd_user_path=/etc/systemd/user
    installer_path=./bin/install.sh

    # Function to build binaries
    function build_binary {
        local binary_name=$1
        local binary_source=$2
        go build -o $binary_name $binary_source

        if [ $? -eq 0 ]; then
            echo "Built $binary_name successfully"
        else
            echo "Failed to build $binary_name"
            exit 1
        fi
    }

    # Function to generate installer
    function generate_installer {
        cat <<EOF > $installer_path
#!/bin/bash
# Path: install.sh

goplay_binary_data="$(base64 $goplay_binary)"
goplayer_binary_data="$(base64 $goplayer_binary)"
service_data="$(base64 $service_file)"

install_yt-dlp() {
    echo "Installing yt-dlp"
    sudo curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux -o /usr/local/bin/yt-dlp
    sudo chmod a+rx /usr/local/bin/yt-dlp
}

install_ffmpeg() {
    echo "Installing ffmpeg"
    if command -v apt > /dev/null; then
        sudo apt install -y ffmpeg
    elif command -v dnf > /dev/null; then
        sudo dnf install -y ffmpeg
    elif command -v pacman > /dev/null
    then
        sudo pacman -S ffmpeg
    else
        echo "Could not install ffmpeg. Please install it manually."
        exit 1
    fi
}

check_dependencies() {
    echo "Checking dependencies"
    for dependency in yt-dlp ffmpeg; do
        command -v $dependency > /dev/null || install_$dependency
    done
}

# stopping services
function cleanup {
    echo "Cleaning up"
    echo "Disabling and stopping goplay service..."
    # check if service exists
    # check if service is running
    if systemctl --user is-active --quiet goplay; then
        systemctl --user stop goplay
    fi
    # check if service is enabled
    if systemctl --user is-enabled --quiet goplay; then
        systemctl --user disable goplay
    fi
    echo "Removing files..."
    sudo rm -rf $systemd_user_path/goplay.service  # Remove the old service file
    sudo rm -rf $install_path/goplay
    sudo rm -rf /usr/local/bin/goplay
    sudo rm -rf $install_path/goplayer
    sudo rm -rf /usr/local/bin/goplayer
    systemctl --user daemon-reload
}


function install_goplay {
    echo "Installing goplay to $install_path/goplay"
    echo "\$goplay_binary_data" | base64 -d > $install_path/goplay
    chmod +x $install_path/goplay
    sudo ln -s $install_path/goplay /usr/local/bin/goplay
}

function install_goplayer {
    echo "Installing goplayer to $install_path/goplayer"
    echo "\$goplayer_binary_data" | base64 -d > $install_path/goplayer
    chmod +x $install_path/goplayer
    sudo ln -s $install_path/goplayer /usr/local/bin/goplayer
}

function start_services {
    echo "Starting goplay service"
    systemctl --user daemon-reload
    systemctl --user is-enabled --quiet goplay || systemctl --user enable goplay > /dev/null
    systemctl --user is-active --quiet goplay || systemctl --user start goplay > /dev/null
}

function install_service {
    echo "Installing goplay service"
    mkdir -p $systemd_user_path
    echo "\$service_data" | base64 -d | sudo tee $systemd_user_path/goplay.service > /dev/null
    systemctl --user daemon-reload
}

function main {
    trap cleanup SIGINT
    cleanup
    check_dependencies
    install_goplay
    install_goplayer
    install_service
    start_services
}

main
EOF

    chmod +x $installer_path
    echo "Installer script created: $installer_path"
}

function main {
    echo "Building goplay and goplayer"
    build_binary "$goplay_binary" "client/main.go"
    build_binary "$goplayer_binary" "server/main.go"

    echo "Generating installer"
    generate_installer
}

main

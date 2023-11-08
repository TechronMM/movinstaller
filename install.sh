#!/bin/bash

# Function to install PHP on Linux
install_php_linux() {
    sudo apt-get update
    sudo apt-get install php
}

# Function to install Composer
install_composer() {
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer
    php -r "unlink('composer-setup.php');"
}

# Function to wait for a service to be available
wait_for_service() {
    local service_host="$1"
    local service_port="$2"
    local max_attempts=30
    local attempt=1

    echo "Waiting for $service_host:$service_port to become available..."

    while [ $attempt -le $max_attempts ]; do
        if nc -z "$service_host" "$service_port"; then
            echo "$service_host:$service_port is available."
            break
        fi

        echo "Attempt $attempt/$max_attempts: $service_host:$service_port is not available yet. Retrying in 5 seconds..."
        sleep 5
        ((attempt++))
    done

    if [ $attempt -gt $max_attempts ]; then
        echo "Timed out waiting for $service_host:$service_port to become available. Exiting."
        exit 1
    fi
}

# Check for the -g option to git clone a repository
if [ "$1" == "-g" ]; then
    echo "Cloning the repository..."
    git clone https://github.com/TechronMM/movie-backend.git MovDashboard
    cd MovDashboard
fi

# Check if PHP is installed
if ! command -v php &> /dev/null; then
    echo "PHP is not installed. Installing PHP..."
    # Check if the OS is macOS
    if [ "$(uname)" == "Darwin" ]; then
        brew install php
    # Check if the OS is Linux
    elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
        install_php_linux
    else
        echo "Unsupported operating system. Please install PHP manually."
        exit 1
    fi
fi

# Check if Composer is installed
if ! command -v composer &> /dev/null; then
    echo "Composer is not installed. Installing Composer..."
    if [ "$(uname)" == "Darwin" ]; then
        brew install composer
    # Check if the OS is Linux
    elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
        install_composer
    else
        echo "Unsupported operating system. Please install Composer manually."
        exit 1
    fi
fi

# Check if Docker is installed (required for Laravel Sail)
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install Docker before proceeding."
    exit 1
fi

# Copy .env.example to .env
cp .env.example .env

# Run composer install
composer install
clear

# Check if Laravel Sail is installed, and install it if not
# if [ ! -f "docker-compose.yml" ]; then
#     echo "Laravel Sail is not installed. Installing Laravel Sail..."
#     echo "Choose to install MariaDB, Redis, Minio, Mailhog with number"
#     echo "eg : 2,3,6,7"
#     php artisan sail:install --with=mariadb,redis,minio,mailpit
#     ./vendor/bin.sail up -d
#     wait_for_service "mariadb" "3306"
# fi

# Run database migrations and other commands
php artisan sail:install --with=mariadb,redis,minio,mailpit
./vendor/bin.sail up -d
wait_for_service "127.0.0.1" "3306"
./vendor/bin/sail artisan migrate:fresh --seed
./vendor/bin/sail artisan passport:install
./vendor/bin/sail artisan storage:link

echo "Setup complete! Your Laravel Sail environment is ready."

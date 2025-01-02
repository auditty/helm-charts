#!/bin/sh

# Add all supported platforms here
get_version_url() {
    if [ "$os_type" == "FreeBSD" ]&&[ "$arch" == "amd64" ]; then
        echo "https://github.com/auditty/helm-charts/releases/download/0.1.23/auditty-0.1.23-FreeBSD-amd64.zip"
    else
        echo "Unsupported operating system and/or architecture: $os_type $arch"
        exit 1
    fi
}

install_freebsd() {
    echo "Installing Auditty for FreeBSD"
    echo "Downloading..."
    mkdir -p /tmp/auditty > /dev/null 2>&1
    original_dir=$(pwd)
    cd /tmp/auditty > /dev/null 2>&1
    fetch -o auditty.zip ${DOWNLOAD_URL}
    fetch -o auditty.zip.sha256 ${DOWNLOAD_URL}.sha256
    # make sure both files arrived
    if [ ! -f auditty.zip ] || [ ! -f auditty.zip.sha256 ]; then
        echo "Failed to download files"
        cd $original_dir
        rm -rf /tmp/auditty
        exit 1
    fi
    # validate the sha256 checksum
    shasum=$(cat auditty.zip.sha256)
    sha256 -q auditty.zip | grep -i $shasum >/dev/null
    if [ $? -ne 0 ]; then
        echo "SHA256 checksum failed"
        cd $original_dir
        rm -rf /tmp/auditty
        exit 1
    fi
    unzip auditty.zip
    # make sure all the files are here
    if [ ! -f auditty ] || [ ! -f auditty-supervisor ] || [ ! -f config.yaml ] || [ ! -f optimizer ]; then
        echo "Failed to extract files"
        cd $original_dir
        rm -rf /tmp/auditty
        exit 1
    fi
    chmod +x auditty auditty-supervisor optimizer
    # First install or upgrade
    if [ ! -f /etc/auditty/config.yaml ]; then
        # validate license
        ./auditty --silent-license-validation $org_name $license_key
        if [ $? -ne 0 ]; then
            echo "License validation failed. Aborting."
            cd $original_dir
            rm -rf /tmp/auditty
            exit 1
        fi
        # replace org_name and license_key in config.yaml with ORG_NAME and LICENSE_KEY
        sed -i "s/ORG_NAME/$org_name/" config.yaml
        sed -i "s/LICENSE_KEY/$license_key/" config.yaml
        mv config.yaml /etc/auditty/config.yaml
    fi
    # Every install or upgrade
    mv auditty /usr/local/bin/auditty
    mv auditty-supervisor /usr/local/bin/auditty-supervisor
    mv optimizer /usr/local/bin/optimizer
    mkdir -p /var/log/auditty
    [ ! -f /var/log/auditty/auditty.log ] && echo "Created log file" > /var/log/auditty/auditty.log
    chmod 755 /var/log/auditty/auditty.log
    # Wrap it up
    cd $original_dir
    rm -rf /tmp/auditty
    # Start the service
    /usr/local/bin/auditty status > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "Installation complete. Restarting Auditty..."
        /usr/local/bin/auditty stop > /dev/null 2>&1
        /usr/local/bin/auditty start
        exit $?
    else
        echo "Installation complete. Starting Auditty..."
        /usr/local/bin/auditty start
        exit $?
    fi
}

# Default values
org_name=""
license_key=""

# Function to display usage information
usage() {
  echo "Usage: $0 --org <OrgName> --key <LicenseKey>"
  exit 1
}

# Parse arguments
while [ "$#" -gt 0 ]; do
  case "$1" in
    --org)
      shift
      org_name="$1"
      ;;
    --key)
      shift
      license_key="$1"
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      ;;
  esac
  shift
done

# Validate inputs
if [ -z "$org_name" ] || [ -z "$license_key" ]; then
    # If there's no config file, we need to validate the license from the command line.
    # If it's there, we'll skip the license validation.
    if [ ! -f /etc/auditty/config.yaml ]; then  
        echo "Error: Both --org and --key are required."
        usage
    fi
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Please use 'sudo' or run as the root user."
  echo "sudo sh -s -- --org ORG --key KEY"
  exit 1
fi

# Main logic
echo "Starting installation for $org_name"

# Identify the system
os_type=$(uname -s)
os_version=$(uname -r)
arch=$(uname -m)

echo "Operating System: $os_type"
echo "Version: $os_version"
echo "Architecture: $arch"

DOWNLOAD_URL=$(get_version_url)

case $os_type in
    FreeBSD)
        install_freebsd
        ;;
    *)
        echo "Unsupported operating system: $os_type"
        exit 1
        ;;
esac

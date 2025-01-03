#!/bin/sh

# Auditty install script for all supported platforms
#
# Fetch (FreeBSD)
# fetch -o - https://helm.auditty.ai/install.sh | sh -s -- --org <orgName> --key <licenseKey>
#
# Curl (Linux)
# curl -s https://helm.auditty.ai/install.sh | sh -s -- --org <orgName> --key <licenseKey>
#
# Wget (Linux)
# wget -qO- https://helm.auditty.ai/install.sh | sh -s -- --org <orgName> --key <licenseKey>


# Add all supported platforms here

# os_name    |  FreeBSD           |  Amazon Linux                      |  Ubuntu              |
# os_type    |  FreeBSD           |  Linux                             |  Linux               |
# os_version |  13.2-RELEASE-p11  |  6.1.119-129.201.amzn2023.x86_64   |  6.8.0-1018-aws      |
# arch       |  amd64             |  x86_64                            |  x86_64              |
get_version_url() {
    if [ "$os_name" == "FreeBSD" ]&&[ "$arch" == "amd64" ]; then
        echo "https://github.com/auditty/helm-charts/releases/download/${AUDITTY_VERSION}/auditty-${AUDITTY_VERSION}-FreeBSD-amd64.zip"
    elif [ "$os_name" == "Amazon Linux" ]&&[ "$arch" == "x86_64" ]; then
        echo "https://github.com/auditty/helm-charts/releases/download/${AUDITTY_VERSION}/auditty-${AUDITTY_VERSION}-Linux-amd64.zip"
    elif [ "$os_name" == "Ubuntu" ]&&[ "$arch" == "x86_64" ]; then
        echo "https://github.com/auditty/helm-charts/releases/download/${AUDITTY_VERSION}/auditty-${AUDITTY_VERSION}-Linux-amd64.zip"
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
        ./optimizer --silent-license-validation $org_name $license_key
        if [ $? -ne 0 ]; then
            echo "License validation failed. Aborting."
            cd $original_dir
            rm -rf /tmp/auditty
            exit 1
        fi
        # replace org_name and license_key in config.yaml with ORG_NAME and LICENSE_KEY
        sed -i "" "s/ORG_NAME/$org_name/" config.yaml
        sed -i "" "s/LICENSE_KEY/$license_key/" config.yaml
        mv config.yaml /etc/auditty/config.yaml
    fi
    # Every install or upgrade
    mv auditty /usr/local/bin/auditty
    mv auditty-supervisor /usr/local/bin/auditty-supervisor
    mv optimizer /usr/local/bin/optimizer
    mkdir -p /var/log/auditty
    [ ! -f /var/log/auditty/optimizer.log ] && echo "Created log file" > /var/log/auditty/optimizer.log
    chmod 755 /var/log/auditty/optimizer.log
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
        echo "Installation complete."
        /usr/local/bin/auditty start
        exit $?
    fi
}

install_linux() {
    echo "Installing Auditty for Linux"
    echo "Downloading..."
    workdir=$(mktemp -d)
    pushd $workdir > /dev/null
    curl -so auditty.zip ${DOWNLOAD_URL}
    curl -so auditty.zip.sha256 ${DOWNLOAD_URL}.sha256
    # make sure both files arrived
    if [ ! -f auditty.zip ] || [ ! -f auditty.zip.sha256 ]; then
        echo "Failed to download files"
        popd > /dev/null
        rm -rf $workdir
        exit 1
    fi
    # validate the sha256 checksum
    shasum=$(cat auditty.zip.sha256)
    sha256 -q auditty.zip | grep -i $shasum >/dev/null
    if [ $? -ne 0 ]; then
        echo "SHA256 checksum failed"
        popd > /dev/null
        rm -rf $workdir
        exit 1
    fi
    unzip auditty.zip
    # make sure all the files are here
    if [ ! -f auditty ] || [ ! -f auditty-supervisor ] || [ ! -f config.yaml ] || [ ! -f optimizer ]; then
        echo "Failed to extract files"
        popd > /dev/null
        rm -rf $workdir
        exit 1
    fi
    chmod +x auditty auditty-supervisor optimizer
    # First install or upgrade
    if [ ! -f /etc/auditty/config.yaml ]; then
        # validate license
        ./optimizer --silent-license-validation $org_name $license_key
        if [ $? -ne 0 ]; then
            echo "License validation failed. Aborting."
            popd > /dev/null
            rm -rf $workdir
            exit 1
        fi
        # replace org_name and license_key in config.yaml with ORG_NAME and LICENSE_KEY
        sed -i "" "s/ORG_NAME/$org_name/" config.yaml
        sed -i "" "s/LICENSE_KEY/$license_key/" config.yaml
        mv config.yaml /etc/auditty/config.yaml
    fi
    # Every install or upgrade
    mv auditty /usr/local/bin/auditty
    mv auditty-supervisor /usr/local/bin/auditty-supervisor
    mv optimizer /usr/local/bin/optimizer
    mkdir -p /var/log/auditty
    [ ! -f /var/log/auditty/optimizer.log ] && echo "Created log file" > /var/log/auditty/optimizer.log
    chmod 755 /var/log/auditty/optimizer.log
    # Wrap it up
    popd > /dev/null
    rm -rf $workdir
    # Start the service
    /usr/local/bin/auditty status > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "Installation complete. Restarting Auditty..."
        /usr/local/bin/auditty stop > /dev/null 2>&1
        /usr/local/bin/auditty start
        exit $?
    else
        echo "Installation complete."
        /usr/local/bin/auditty start
        exit $?
    fi
}

_divider="--------------------------------------------------"
_prompt=">>>"
_indent="   "

# ASCII Art
header() {
    cat 1>&2 <<'EOF'

 ▗▄▖ ▗▖ ▗▖▗▄▄▄ ▗▄▄▄▖▗▄▄▄▖▗▄▄▄▖▗▖  ▗▖
▐▌ ▐▌▐▌ ▐▌▐▌  █  █    █    █   ▝▚▞▘ 
▐▛▀▜▌▐▌ ▐▌▐▌  █  █    █    █    ▐▌  
▐▌ ▐▌▝▚▄▞▘▐▙▄▄▀▗▄█▄▖  █    █    ▐▌  
                                    
                  Data that matters.
$_divider
Website: https://auditty.ai
Docs: https://app.auditty.ai/docs
Support: support@auditty.ai
$_divider
EOF
}

# Default values
org_name=""
license_key=""
AUDITTY_VERSION="0.1.23"

# Function to display usage information
usage() {
  echo "Usage: $0 [--org <OrgName> --key <LicenseKey>]"
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
        echo "Error: Both --org and --key are required for initial installation."
        usage
    fi
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Please use 'sudo' or run as the root user."
  echo "sudo sh -s -- [--org <ORG> --key <KEY>]"
  exit 1
fi

# Main logic
echo "Starting installation for $org_name"

# Identify the system

if [ -f /etc/os-release ]; then
    os_name=$(awk -F= '/^NAME=/{gsub(/"/, "", $2); print $2}' /etc/os-release)
else
    os_name="Unknown"
fi
os_type=$(uname -s)
os_version=$(uname -r)
arch=$(uname -m)

echo "Operating System: $os_name"
echo "Version: $os_version"
echo "Architecture: $arch"

DOWNLOAD_URL=$(get_version_url)

case $os_type in
    FreeBSD)
        install_freebsd
        ;;
    Linux)
        install_freebsd
        ;;
    *)
        echo "Unsupported operating system: $os_type"
        exit 1
        ;;
esac

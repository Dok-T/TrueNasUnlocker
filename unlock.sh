#!/bin/bash

# Set script to exit on error
set -e

# Enable logging
exec > >(tee -i /var/log/setup-script.log)
exec 2>&1

# Colors for fancy output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "Starting script execution..."

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}This script must be run as root. Please use sudo or run as root user.${NC}"
    exit 1
fi

# Fix export path
echo "Fixing export path..."
export PATH=/usr/bin:/usr/sbin:/bin:/sbin

# Function to check if a partition is mounted as RW
is_mounted_rw() {
    local mount_point=$1
    mount | grep " on $mount_point " | grep -q "rw,"
}

# Function to remount a partition
remount() {
    local mount_point=$1
    local mode=$2
    echo "Remounting $mount_point in $mode mode..."
    mount -o remount,$mode "$mount_point"
}

# Function to check if apt and dpkg are unlocked
is_apt_dpkg_unlocked() {
    [ -x /bin/apt ] && [ -x /usr/bin/dpkg ]
}

# Function to unlock apt and dpkg
unlock_apt_dpkg() {
    echo "Enabling apt utilities..."
    chmod +x /bin/apt*
    chmod +x /usr/bin/dpkg

    echo "Unlocking any potential locks for apt and dpkg..."
    rm -f /var/lib/dpkg/lock
    rm -f /var/lib/apt/lists/lock
    rm -f /var/cache/apt/archives/lock
}

# Function to lock apt and dpkg
lock_apt_dpkg() {
    echo "Disabling apt utilities..."
    chmod -x /bin/apt*
    chmod -x /usr/bin/dpkg
}

# Initial state check and display
echo -e "${YELLOW}Current system state:${NC}"

if is_mounted_rw '/usr'; then
    echo -e "/usr is ${GREEN}mounted as RW${NC}"
else
    echo -e "/usr is ${RED}mounted as RO${NC}"
fi

if is_mounted_rw '/opt'; then
    echo -e "/opt is ${GREEN}mounted as RW${NC}"
else
    echo -e "/opt is ${RED}mounted as RO${NC}"
fi

if is_apt_dpkg_unlocked; then
    echo -e "APT and DPKG are ${GREEN}unlocked${NC}"
else
    echo -e "APT and DPKG are ${RED}locked${NC}"
fi

# Remount or revert based on current state
if is_mounted_rw '/usr'; then
    read -p "/usr is mounted as RW. Do you want to remount it as RO? (yes/no): " remount_usr_choice
    if [[ $remount_usr_choice == "yes" ]]; then
        remount 'boot-pool/ROOT/24.04.1.1/usr' ro
    else
        echo "Skipping remount of /usr as RO."
    fi
else
    remount 'boot-pool/ROOT/24.04.1.1/usr' rw
fi

if is_mounted_rw '/opt'; then
    read -p "/opt is mounted as RW. Do you want to remount it as RO? (yes/no): " remount_opt_choice
    if [[ $remount_opt_choice == "yes" ]]; then
        remount '/opt' ro
    else
        echo "Skipping remount of /opt as RO."
    fi
else
    remount '/opt' rw
fi

# Unlock or lock apt and dpkg based on current state
if is_apt_dpkg_unlocked; then
    read -p "APT and DPKG are unlocked. Do you want to lock them? (yes/no): " lock_choice
    if [[ $lock_choice == "yes" ]]; then
        lock_apt_dpkg
        echo "APT and DPKG have been locked."
    else
        echo "Skipping locking of APT and DPKG."
    fi
else
    read -p "Do you want to unlock APT and DPKG? (yes/no): " unlock_choice
    if [[ $unlock_choice == "yes" ]]; then
        unlock_apt_dpkg
        echo "APT and DPKG have been unlocked."
    else
        echo "Skipping unlocking of APT and DPKG."
    fi
fi

echo "Script execution completed successfully."
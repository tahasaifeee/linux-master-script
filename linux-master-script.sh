#!/bin/bash

###############################################################################
# Linux Master Script - Universal Management Tool
# Compatible with: CentOS 6+, Ubuntu 16+, Debian, AlmaLinux, Rocky, Oracle
###############################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

###############################################################################
# Password Authentication Configuration
###############################################################################
# IMPORTANT: Change this password hash for security!
# To generate a new password hash, run:
# echo -n "your_password" | sha256sum | cut -d' ' -f1
#
# Default password: "LinuxAdmin2024"
# Default hash below - CHANGE THIS!
SCRIPT_PASSWORD_HASH="990ef64f2f6d518e4f67ad25cb5f4cf5dc676277c10ccbd530ae34cea0020e5c"

# Maximum login attempts
MAX_ATTEMPTS=3

###############################################################################
# Password Authentication Function
###############################################################################

authenticate_user() {
    local attempts=0
    local authenticated=false

    print_header "Authentication Required"
    echo -e "${YELLOW}This script is password protected.${NC}"
    echo -e "${BLUE}Contact your administrator if you don't have access.${NC}\n"

    while [ $attempts -lt $MAX_ATTEMPTS ]; do
        # Prompt for password (silent input)
        echo -n "Enter password: "
        read -s user_password
        echo ""

        # Generate hash of entered password
        entered_hash=$(echo -n "$user_password" | sha256sum | cut -d' ' -f1)

        # Compare hashes
        if [ "$entered_hash" = "$SCRIPT_PASSWORD_HASH" ]; then
            authenticated=true
            break
        else
            attempts=$((attempts + 1))
            remaining=$((MAX_ATTEMPTS - attempts))

            if [ $remaining -gt 0 ]; then
                print_error "Invalid password. $remaining attempt(s) remaining."
            fi
        fi

        # Clear password variable
        user_password=""
    done

    if [ "$authenticated" = false ]; then
        print_error "Authentication failed. Maximum attempts exceeded."
        print_error "Access denied. Exiting..."
        exit 1
    fi

    print_success "Authentication successful!\n"
    sleep 1
}

###############################################################################
# Utility Functions
###############################################################################

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

###############################################################################
# Distribution Detection
###############################################################################

detect_distribution() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
        DISTRO_NAME=$NAME
    elif [ -f /etc/redhat-release ]; then
        if grep -q "CentOS release 6" /etc/redhat-release; then
            DISTRO="centos"
            VERSION="6"
            DISTRO_NAME="CentOS 6"
        elif grep -q "Red Hat Enterprise Linux" /etc/redhat-release; then
            DISTRO="rhel"
            VERSION=$(grep -oE '[0-9]+\.[0-9]+' /etc/redhat-release | cut -d. -f1)
            DISTRO_NAME="Red Hat Enterprise Linux"
        fi
    elif [ -f /etc/debian_version ]; then
        DISTRO="debian"
        VERSION=$(cat /etc/debian_version)
        DISTRO_NAME="Debian"
    else
        DISTRO="unknown"
        VERSION="unknown"
        DISTRO_NAME="Unknown"
    fi

    # Normalize distro names
    case "$DISTRO" in
        rhel|redhat)
            DISTRO="rhel"
            ;;
        centos)
            DISTRO="centos"
            ;;
        almalinux|alma)
            DISTRO="almalinux"
            ;;
        rocky)
            DISTRO="rocky"
            ;;
        ol|oracle|oraclelinux)
            DISTRO="oracle"
            ;;
        ubuntu)
            DISTRO="ubuntu"
            ;;
        debian)
            DISTRO="debian"
            ;;
    esac
}

# Detect package manager
detect_package_manager() {
    if command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
    elif command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt"
    else
        print_error "No supported package manager found"
        exit 1
    fi
}

# Display system information
display_system_info() {
    print_header "System Information"
    echo -e "Distribution: ${GREEN}$DISTRO_NAME${NC}"
    echo -e "Version: ${GREEN}$VERSION${NC}"
    echo -e "Package Manager: ${GREEN}$PKG_MANAGER${NC}"
    echo -e "Kernel: ${GREEN}$(uname -r)${NC}"
    echo -e "Architecture: ${GREEN}$(uname -m)${NC}"
    echo ""
}

###############################################################################
# Package Management Functions
###############################################################################

# Update package repository cache
update_cache() {
    print_info "Updating package cache..."
    case "$PKG_MANAGER" in
        apt)
            apt-get update -y
            ;;
        yum|dnf)
            $PKG_MANAGER makecache
            ;;
    esac
}

# Install package
install_package() {
    local package=$1
    print_info "Installing $package..."

    case "$PKG_MANAGER" in
        apt)
            DEBIAN_FRONTEND=noninteractive apt-get install -y "$package"
            ;;
        yum|dnf)
            $PKG_MANAGER install -y "$package"
            ;;
    esac
}

# Check if package is installed
is_package_installed() {
    local package=$1
    case "$PKG_MANAGER" in
        apt)
            dpkg -l | grep -q "^ii.*$package"
            ;;
        yum|dnf)
            rpm -qa | grep -q "$package"
            ;;
    esac
}

###############################################################################
# Menu Options Implementation
###############################################################################

# Option 1: System Update
system_update() {
    print_header "System Update"

    print_info "Starting system update for $DISTRO_NAME..."

    case "$PKG_MANAGER" in
        apt)
            print_info "Updating package lists..."
            apt-get update -y

            print_info "Upgrading packages..."
            DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

            print_info "Performing distribution upgrade..."
            DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y

            print_info "Removing unnecessary packages..."
            apt-get autoremove -y
            apt-get autoclean -y
            ;;
        yum)
            print_info "Updating all packages..."
            yum update -y

            print_info "Cleaning up..."
            yum clean all
            ;;
        dnf)
            print_info "Updating all packages..."
            dnf update -y

            print_info "Cleaning up..."
            dnf clean all
            ;;
    esac

    print_success "System update completed successfully!"

    # Check if reboot is required
    if [ -f /var/run/reboot-required ]; then
        print_warning "System reboot is required!"
    elif [ "$PKG_MANAGER" != "apt" ]; then
        if needs-restarting &> /dev/null; then
            needs-restarting -r
        fi
    fi
}

# Option 2: List Running Services
list_running_services() {
    print_header "Running Services"

    if command -v systemctl &> /dev/null; then
        print_info "Listing all running services (systemd)..."
        echo ""
        systemctl list-units --type=service --state=running --no-pager
    elif command -v service &> /dev/null; then
        print_info "Listing all running services (SysV init)..."
        echo ""
        service --status-all 2>&1 | grep "+"
    else
        print_error "No supported service manager found"
        return 1
    fi

    echo ""
    print_info "Total running services: $(systemctl list-units --type=service --state=running --no-legend 2>/dev/null | wc -l || service --status-all 2>&1 | grep '+' | wc -l)"
}

# Option 3: Install QEMU Guest Agent
install_qemu_agent() {
    print_header "Install QEMU Guest Agent"

    local package_name=""

    # Determine package name based on distribution
    case "$DISTRO" in
        ubuntu|debian)
            package_name="qemu-guest-agent"
            ;;
        centos|rhel|almalinux|rocky|oracle)
            package_name="qemu-guest-agent"
            ;;
        *)
            print_error "Unsupported distribution for QEMU guest agent installation"
            return 1
            ;;
    esac

    # Check if already installed
    if is_package_installed "$package_name"; then
        print_warning "QEMU Guest Agent is already installed"

        # Check if service is running
        if systemctl is-active --quiet qemu-guest-agent 2>/dev/null || service qemu-guest-agent status &>/dev/null; then
            print_success "QEMU Guest Agent service is running"
        else
            print_warning "QEMU Guest Agent is installed but not running. Starting..."
            start_qemu_agent
        fi
        return 0
    fi

    print_info "Installing QEMU Guest Agent..."
    update_cache
    install_package "$package_name"

    # Start and enable the service
    start_qemu_agent

    print_success "QEMU Guest Agent installation completed!"
}

start_qemu_agent() {
    if command -v systemctl &> /dev/null; then
        systemctl start qemu-guest-agent
        systemctl enable qemu-guest-agent
        print_success "QEMU Guest Agent service started and enabled"
    elif command -v service &> /dev/null; then
        service qemu-guest-agent start
        chkconfig qemu-guest-agent on 2>/dev/null || true
        print_success "QEMU Guest Agent service started"
    fi
}

# Option 4: Install Cloud-Init
install_cloud_init() {
    print_header "Install Cloud-Init"

    local package_name="cloud-init"

    # Check if already installed
    if is_package_installed "$package_name"; then
        print_warning "Cloud-init is already installed"
        cloud-init --version
        return 0
    fi

    print_info "Installing cloud-init..."
    update_cache

    case "$PKG_MANAGER" in
        apt)
            install_package "$package_name"
            ;;
        yum|dnf)
            # For RHEL-based systems, may need EPEL repository
            if [ "$DISTRO" = "centos" ] && [ "${VERSION%%.*}" -eq 6 ]; then
                print_info "Installing EPEL repository for CentOS 6..."
                yum install -y epel-release || rpm -Uvh https://archives.fedoraproject.org/pub/archive/epel/6/x86_64/epel-release-6-8.noarch.rpm
            elif [ "$DISTRO" = "centos" ] && [ "${VERSION%%.*}" -eq 7 ]; then
                print_info "Installing EPEL repository for CentOS 7..."
                yum install -y epel-release
            fi

            install_package "$package_name"
            ;;
    esac

    # Enable cloud-init services
    if command -v systemctl &> /dev/null; then
        systemctl enable cloud-init-local.service
        systemctl enable cloud-init.service
        systemctl enable cloud-config.service
        systemctl enable cloud-final.service
        print_success "Cloud-init services enabled"
    fi

    print_success "Cloud-init installation completed!"
    cloud-init --version

    print_warning "Note: Cloud-init will be fully configured on next boot"
}

###############################################################################
# Main Menu
###############################################################################

show_menu() {
    clear
    display_system_info

    print_header "Linux Master Script - Main Menu"
    echo "1) System Update"
    echo "2) List Running Services"
    echo "3) Install QEMU Guest Agent"
    echo "4) Install Cloud-Init"
    echo "5) Display System Information"
    echo "6) Exit"
    echo ""
    echo -n "Please select an option [1-6]: "
}

main_loop() {
    while true; do
        show_menu
        read -r choice

        case $choice in
            1)
                system_update
                ;;
            2)
                list_running_services
                ;;
            3)
                install_qemu_agent
                ;;
            4)
                install_cloud_init
                ;;
            5)
                display_system_info
                ;;
            6)
                print_info "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid option. Please try again."
                ;;
        esac

        echo ""
        echo -n "Press Enter to continue..."
        read -r
    done
}

###############################################################################
# Main Execution
###############################################################################

main() {
    authenticate_user
    check_root
    detect_distribution
    detect_package_manager
    main_loop
}

# Run main function
main

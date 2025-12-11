#!/bin/bash
###############################################################################
# Refactored Linux Master Script - Universal Management Tool
# Compatible with: CentOS 6+, Ubuntu 16+, Debian, AlmaLinux, Rocky, Oracle
# This version uses modular design with shared utilities
###############################################################################

set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common_utils.sh"

# Global variables
declare -g SSHD_SERVICE="sshd"
declare -g SSH_CONFIG="/etc/ssh/sshd_config"

###############################################################################
# Service-specific Functions
###############################################################################

display_system_info() {
    print_header "System Information"
    echo -e "Distribution: ${GREEN}$DISTRO_NAME${NC}"
    echo -e "Version: ${GREEN}$VERSION${NC}"
    echo -e "Package Manager: ${GREEN}$PKG_MANAGER${NC}"
    echo -e "Kernel: ${GREEN}$(uname -r)${NC}"
    echo -e "Architecture: ${GREEN}$(uname -m)${NC}"
    echo ""
}

# Option 1: System Update
system_update() {
    print_header "System Update"
    perform_system_update
}

# Option 2: List Running Services
list_running_services_menu() {
    print_header "Running Services"

    print_status info "Listing all running services..."
    echo ""
    
    list_running_services
    
    echo ""
    local count
    if command -v systemctl &> /dev/null; then
        count=$(systemctl list-units --type=service --state=running --no-legend 2>/dev/null | wc -l)
    else
        count=$(service --status-all 2>&1 | grep '+' | wc -l)
    fi
    print_status info "Total running services: $count"
}

# Option 3: Install QEMU Guest Agent
install_qemu_agent() {
    print_header "Install QEMU Guest Agent"

    local package_name="qemu-guest-agent"

    # Check if already installed
    if is_package_installed "$package_name"; then
        print_status warning "QEMU Guest Agent is already installed"

        # Check if service is running
        if systemctl is-active --quiet qemu-guest-agent 2>/dev/null || service qemu-guest-agent status &>/dev/null; then
            print_status success "QEMU Guest Agent service is running"
        else
            print_status warning "QEMU Guest Agent is installed but not running. Starting..."
            start_qemu_agent
        fi
        return 0
    fi

    print_status info "Installing QEMU Guest Agent..."
    update_cache
    install_package "$package_name"

    # Start and enable the service
    start_qemu_agent

    print_status success "QEMU Guest Agent installation completed!"
}

start_qemu_agent() {
    if command -v systemctl &> /dev/null; then
        systemctl start qemu-guest-agent
        systemctl enable qemu-guest-agent
        print_status success "QEMU Guest Agent service started and enabled"
    elif command -v service &> /dev/null; then
        service qemu-guest-agent start
        chkconfig qemu-guest-agent on 2>/dev/null || true
        print_status success "QEMU Guest Agent service started"
    fi
}

# Option 4: Install Cloud-Init
install_cloud_init() {
    print_header "Install Cloud-Init"

    local package_name="cloud-init"

    # Check if already installed
    if is_package_installed "$package_name"; then
        print_status warning "Cloud-init is already installed"
        cloud-init --version
        return 0
    fi

    print_status info "Installing cloud-init..."
    update_cache

    case "$PKG_MANAGER" in
        apt)
            install_package "$package_name"
            ;;
        yum|dnf)
            # For RHEL-based systems, may need EPEL repository
            if [ "$DISTRO" = "centos" ] && [ "${VERSION%%.*}" -eq 6 ]; then
                print_status info "Installing EPEL repository for CentOS 6..."
                yum install -y epel-release || rpm -Uvh https://archives.fedoraproject.org/pub/archive/epel/6/x86_64/epel-release-6-8.noarch.rpm
            elif [ "$DISTRO" = "centos" ] && [ "${VERSION%%.*}" -eq 7 ]; then
                print_status info "Installing EPEL repository for CentOS 7..."
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
        print_status success "Cloud-init services enabled"
    fi

    print_status success "Cloud-init installation completed!"
    cloud-init --version

    print_status warning "Note: Cloud-init will be fully configured on next boot"
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
                list_running_services_menu
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
                print_status info "Exiting..."
                exit 0
                ;;
            *)
                print_status error "Invalid option. Please try again."
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
    check_root
    detect_distribution
    detect_package_manager
    main_loop
}

# Run main function
main "$@"
#!/bin/bash
###############################################################################
# Common Utilities Module
# Shared functions for Linux system management scripts
###############################################################################

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly NC='\033[0m' # No Color

# Global configuration
declare -g CONFIG_FILE=""
declare -g LOG_FILE=""

###############################################################################
# Logging Functions
###############################################################################

log_info() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $message" | tee -a "$LOG_FILE" >&2
}

log_success() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $message" | tee -a "$LOG_FILE" >&2
}

log_warning() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARNING] $message" | tee -a "$LOG_FILE" >&2
}

log_error() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $message" | tee -a "$LOG_FILE" >&2
}

###############################################################################
# Utility Functions
###############################################################################

print_header() {
    local title="$1"
    echo -e "\\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$title${NC}"
    echo -e "${BLUE}========================================${NC}\\n"
}

print_status() {
    local status="$1"
    local message="$2"
    case "$status" in
        success) echo -e "${GREEN}✓ [SUCCESS]${NC} $message" ;;
        warning) echo -e "${YELLOW}⚠ [WARNING]${NC} $message" ;;
        error) echo -e "${RED}✗ [ERROR]${NC} $message" ;;
        info) echo -e "${BLUE}ℹ [INFO]${NC} $message" ;;
        step) echo -e "${CYAN}➜ $message${NC}" ;;
        result) echo -e "${MAGENTA}  → $message${NC}" ;;
    esac
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_status error "This script must be run as root"
        exit 1
    fi
}

# Ask yes/no question
ask_yes_no() {
    local question="$1"
    local response
    while true; do
        echo -ne "${YELLOW}$question [y/n]: ${NC}"
        read -r response
        case "$response" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

# Ask for input with default value
ask_input() {
    local question="$1"
    local default="$2"
    local response
    echo -ne "${YELLOW}$question${NC}"
    if [ -n "$default" ]; then
        echo -ne " ${CYAN}[default: $default]${NC}"
    fi
    echo -ne ": "
    read -r response
    if [ -z "$response" ] && [ -n "$default" ]; then
        echo "$default"
    else
        echo "$response"
    fi
}

validate_port() {
    local port="$1"
    if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
        return 0
    else
        return 1
    fi
}

###############################################################################
# Distribution Detection
###############################################################################

detect_distribution() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO="$ID"
        VERSION="$VERSION_ID"
        DISTRO_NAME="$NAME"
    elif [ -f /etc/redhat-release ]; then
        if grep -q "CentOS release 6" /etc/redhat-release; then
            DISTRO="centos"
            VERSION="6"
            DISTRO_NAME="CentOS 6"
        elif grep -q "Red Hat Enterprise Linux" /etc/redhat-release; then
            DISTRO="rhel"
            VERSION=$(grep -oE '[0-9]+\\.[0-9]+' /etc/redhat-release | cut -d. -f1)
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
        rhel|redhat) DISTRO="rhel" ;;
        centos) DISTRO="centos" ;;
        almalinux|alma) DISTRO="almalinux" ;;
        rocky) DISTRO="rocky" ;;
        ol|oracle|oraclelinux) DISTRO="oracle" ;;
        ubuntu) DISTRO="ubuntu" ;;
        debian) DISTRO="debian" ;;
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
        print_status error "No supported package manager found"
        exit 1
    fi
}

###############################################################################
# Package Management Functions
###############################################################################

update_cache() {
    case "$PKG_MANAGER" in
        apt)
            apt-get update -y &> /dev/null
            ;;
        yum|dnf)
            $PKG_MANAGER makecache &> /dev/null
            ;;
    esac
}

install_package() {
    local package="$1"
    case "$PKG_MANAGER" in
        apt)
            DEBIAN_FRONTEND=noninteractive apt-get install -y "$package" &> /dev/null
            ;;
        yum|dnf)
            $PKG_MANAGER install -y "$package" &> /dev/null
            ;;
    esac
}

is_package_installed() {
    local package="$1"
    case "$PKG_MANAGER" in
        apt)
            dpkg -l | grep -q "^ii.*$package"
            ;;
        yum|dnf)
            rpm -qa | grep -q "$package"
            ;;
    esac
}

# System update function
perform_system_update() {
    print_status info "Starting system update for $DISTRO_NAME..."

    case "$PKG_MANAGER" in
        apt)
            print_status info "Updating package lists..."
            apt-get update -y

            print_status info "Upgrading packages..."
            DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

            print_status info "Performing distribution upgrade..."
            DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y

            print_status info "Removing unnecessary packages..."
            apt-get autoremove -y
            apt-get autoclean -y
            ;;
        yum)
            print_status info "Updating all packages..."
            yum update -y

            print_status info "Cleaning up..."
            yum clean all
            ;;
        dnf)
            print_status info "Updating all packages..."
            dnf update -y

            print_status info "Cleaning up..."
            dnf clean all
            ;;
    esac

    print_status success "System update completed successfully!"

    # Check if reboot is required
    if [ -f /var/run/reboot-required ]; then
        print_status warning "System reboot is required!"
        return 1
    elif [ "$PKG_MANAGER" != "apt" ]; then
        if command -v needs-restarting &> /dev/null; then
            if needs-restarting -r &> /dev/null; then
                print_status warning "System reboot is required!"
                return 1
            fi
        fi
    fi
    return 0
}

###############################################################################
# Service Management Functions
###############################################################################

list_running_services() {
    if command -v systemctl &> /dev/null; then
        systemctl list-units --type=service --state=running --no-pager
    elif command -v service &> /dev/null; then
        service --status-all 2>&1 | grep "+"
    else
        print_status error "No supported service manager found"
        return 1
    fi
}

###############################################################################
# Configuration and Setup Functions
###############################################################################

create_backup() {
    local file="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${file}.bak.${timestamp}"
    
    cp "$file" "$backup_file"
    log_info "Created backup: $backup_file"
    echo "$backup_file"
}

###############################################################################
# Initialization
###############################################################################

initialize_common_utils() {
    # Set up logging
    LOG_FILE="/tmp/$(basename "$0" .sh)_$(date +%Y%m%d_%H%M%S).log"
    
    # Log script start
    log_info "Script started: $(basename "$0")"
}

# Initialize when sourced
initialize_common_utils
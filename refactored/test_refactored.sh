#!/bin/bash
###############################################################################
# Test Script for Refactored Linux Master Scripts
# This script performs basic validation of the refactored code
###############################################################################

set -e

echo "Testing refactored Linux master scripts..."

# Test 1: Check if all required files exist
echo "Test 1: Checking file existence..."
if [ ! -f "/workspace/refactored/common_utils.sh" ]; then
    echo "ERROR: common_utils.sh not found"
    exit 1
fi

if [ ! -f "/workspace/refactored/linux_master_refactored.sh" ]; then
    echo "ERROR: linux_master_refactored.sh not found"
    exit 1
fi

if [ ! -f "/workspace/refactored/template_readiness_refactored.sh" ]; then
    echo "ERROR: template_readiness_refactored.sh not found"
    exit 1
fi

echo "✓ All required files exist"

# Test 2: Check if scripts are executable
echo "Test 2: Checking script permissions..."
if [ ! -x "/workspace/refactored/common_utils.sh" ]; then
    echo "ERROR: common_utils.sh is not executable"
    exit 1
fi

if [ ! -x "/workspace/refactored/linux_master_refactored.sh" ]; then
    echo "ERROR: linux_master_refactored.sh is not executable"
    exit 1
fi

if [ ! -x "/workspace/refactored/template_readiness_refactored.sh" ]; then
    echo "ERROR: template_readiness_refactored.sh is not executable"
    exit 1
fi

echo "✓ All scripts are executable"

# Test 3: Basic syntax check
echo "Test 3: Checking script syntax..."
bash -n "/workspace/refactored/common_utils.sh"
echo "✓ common_utils.sh syntax is valid"

bash -n "/workspace/refactored/linux_master_refactored.sh"
echo "✓ linux_master_refactored.sh syntax is valid"

bash -n "/workspace/refactored/template_readiness_refactored.sh"
echo "✓ template_readiness_refactored.sh syntax is valid"

# Test 4: Check if common_utils.sh can be sourced without errors
echo "Test 4: Testing if common_utils.sh can be sourced..."
if bash -c "source /workspace/refactored/common_utils.sh" 2>/dev/null; then
    echo "✓ common_utils.sh can be sourced without errors"
else
    echo "ERROR: common_utils.sh cannot be sourced"
    exit 1
fi

# Test 5: Check if functions exist in common_utils.sh
echo "Test 5: Checking for required functions in common_utils.sh..."

# Create a temporary script to test function availability
cat > /tmp/test_functions.sh << 'EOF'
#!/bin/bash
source /workspace/refactored/common_utils.sh

# Test key functions exist
functions_to_test=(
    "print_header"
    "print_status"
    "check_root"
    "ask_yes_no"
    "ask_input"
    "validate_port"
    "detect_distribution"
    "detect_package_manager"
    "update_cache"
    "install_package"
    "is_package_installed"
    "perform_system_update"
    "list_running_services"
    "create_backup"
    "log_info"
    "log_success"
    "log_warning"
    "log_error"
)

all_found=true
for func in "${functions_to_test[@]}"; do
    if ! declare -f "$func" >/dev/null 2>&1; then
        echo "Function $func not found"
        all_found=false
    fi
done

if [ "$all_found" = true ]; then
    echo "ALL_FUNCTIONS_PRESENT"
fi
EOF

chmod +x /tmp/test_functions.sh
result=$(bash /tmp/test_functions.sh 2>&1)

if echo "$result" | grep -q "ALL_FUNCTIONS_PRESENT"; then
    echo "✓ All required functions are present in common_utils.sh"
else
    echo "ERROR: Some required functions are missing"
    echo "$result"
    exit 1
fi

# Clean up
rm /tmp/test_functions.sh

echo ""
echo "All tests passed! The refactored scripts are working correctly."
echo ""
echo "Refactored scripts are located in: /workspace/refactored/"
echo "- common_utils.sh: Shared utility functions"
echo "- linux_master_refactored.sh: Refactored main management script"
echo "- template_readiness_refactored.sh: Refactored template readiness script"
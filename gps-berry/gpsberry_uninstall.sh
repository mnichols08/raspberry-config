#!/bin/bash

# GPSBerry Uninstall Script
# This script reverses changes made by the GPSBerry installation scripts
# It removes GPS packages, restores serial configuration, and cleans up files
# Usage: Run this script as root or with sudo privileges.
# Author: Mikey Nichols

# Color codes for better visual feedback
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Global variables
INTERACTIVE=true
DRY_RUN=false
LOG_FILE="/tmp/gpsberry-uninstall.log"
KEEP_PACKAGES=false
KEEP_CONFIGS=false
RESTORE_BACKUPS=true
VERBOSE=false
FORCE_REMOVE=false

# Function to display usage information
show_usage() {
    echo "GPSBerry Uninstall Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -n, --non-interactive   Run in non-interactive mode"
    echo "  -d, --dry-run           Show what would be done without making changes"
    echo "  -l, --log FILE          Specify custom log file (default: $LOG_FILE)"
    echo "  -v, --verbose           Enable verbose output"
    echo ""
    echo "Uninstall Options:"
    echo "  --keep-packages         Don't remove GPS-related packages"
    echo "  --keep-configs          Don't modify serial/UART configuration"
    echo "  --no-restore-backups    Don't restore configuration backups"
    echo "  --force                 Force removal without safety checks"
    echo "  --list-changes          Show what would be removed/changed"
    echo ""
    echo "Safety Options:"
    echo "  --backup-current        Create backup of current state before changes"
    echo "  --restore-only          Only restore backups, don't remove packages"
    echo ""
    echo "Examples:"
    echo "  $0                              # Interactive uninstall"
    echo "  $0 --dry-run                    # Preview changes"
    echo "  $0 --keep-packages             # Remove configs only"
    echo "  $0 --non-interactive --force   # Automated removal"
    echo "  $0 --restore-only              # Just restore backups"
    echo "  $0 --list-changes              # Show what's installed"
}

# Function to log messages
log_message() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Function to print colored output
print_color() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

# Function to print status messages
print_status() {
    print_color $BLUE "ℹ  $@"
    log_message "INFO" "$@"
}

print_success() {
    print_color $GREEN "✓ $@"
    log_message "SUCCESS" "$@"
}

print_warning() {
    print_color $YELLOW "⚠  $@"
    log_message "WARNING" "$@"
}

print_error() {
    print_color $RED "✗ $@"
    log_message "ERROR" "$@"
}

print_debug() {
    if [ "$VERBOSE" = true ]; then
        print_color $PURPLE "🔍 $@"
        log_message "DEBUG" "$@"
    fi
}

# Function to ask yes/no questions
ask_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    
    if [ "$INTERACTIVE" = false ]; then
        print_status "Non-interactive mode: defaulting to '$default' for: $prompt"
        [[ $default == "y" ]] && return 0 || return 1
    fi
    
    while true; do
        if [ "$default" = "y" ]; then
            read -p "$prompt (Y/n): " -n 1 -r
        else
            read -p "$prompt (y/N): " -n 1 -r
        fi
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]] || ([[ -z $REPLY ]] && [[ $default == "y" ]]); then
            return 0
        elif [[ $REPLY =~ ^[Nn]$ ]] || ([[ -z $REPLY ]] && [[ $default == "n" ]]); then
            return 1
        else
            print_warning "Please answer y or n."
        fi
    done
}

# Function to find and list configuration backups
find_config_backups() {
    print_status "Scanning for configuration backups..."
    
    local backup_files=()
    
    # Look for timestamped backups
    for pattern in "/boot/config.txt.backup.*" "/boot/cmdline.txt.backup.*" "/tmp/crontab.backup.*"; do
        if ls $pattern 2>/dev/null | head -1 >/dev/null; then
            while IFS= read -r -d '' file; do
                backup_files+=("$file")
            done < <(find $(dirname "$pattern") -name "$(basename "$pattern")" -print0 2>/dev/null)
        fi
    done
    
    if [ ${#backup_files[@]} -gt 0 ]; then
        print_success "Found ${#backup_files[@]} backup file(s):"
        for file in "${backup_files[@]}"; do
            local timestamp=$(stat -c %y "$file" 2>/dev/null | cut -d' ' -f1,2 | cut -d'.' -f1)
            echo "  $file (created: $timestamp)"
            print_debug "Backup size: $(du -h "$file" 2>/dev/null | cut -f1)"
        done
    else
        print_warning "No configuration backups found"
        print_status "Backup patterns searched:"
        echo "  /boot/config.txt.backup.*"
        echo "  /boot/cmdline.txt.backup.*" 
        echo "  /tmp/crontab.backup.*"
    fi
    
    echo
    return ${#backup_files[@]}
}

# Function to analyze current GPS installation
analyze_current_state() {
    print_status "Analyzing current GPS installation state..."
    echo
    
    local changes_found=false
    
    # Check installed packages
    print_color $CYAN "=== Installed GPS Packages ==="
    local gps_packages=$(dpkg -l | grep -E "(gpsd|minicom|screen|python3-gps)" | awk '{print $2 " " $3}')
    if [ -n "$gps_packages" ]; then
        echo "$gps_packages" | sed 's/^/  /'
        changes_found=true
    else
        echo "  No GPS packages found"
    fi
    echo
    
    # Check UART configuration
    print_color $CYAN "=== UART Configuration ==="
    if grep -q "enable_uart=1" /boot/config.txt 2>/dev/null; then
        echo "  ✓ UART enabled in /boot/config.txt"
        print_debug "  Line: $(grep "enable_uart=1" /boot/config.txt)"
        changes_found=true
    else
        echo "  ⚠ UART not explicitly enabled"
    fi
    
    if grep -q "console=serial" /boot/cmdline.txt 2>/dev/null; then
        echo "  ⚠ Serial console enabled in /boot/cmdline.txt"
        print_debug "  Console config: $(grep -o 'console=[^ ]*' /boot/cmdline.txt | head -1)"
    else
        echo "  ✓ Serial console disabled"
        changes_found=true
    fi
    echo
    
    # Check running services
    print_color $CYAN "=== GPS Services ==="
    if systemctl is-active gpsd >/dev/null 2>&1; then
        echo "  ✓ GPSD service is active"
        print_debug "  Status: $(systemctl is-active gpsd) | Enabled: $(systemctl is-enabled gpsd 2>/dev/null)"
        changes_found=true
    else
        echo "  ⚠ GPSD service not active"
    fi
    
    if pgrep -f gpsd >/dev/null; then
        local gpsd_pids=$(pgrep -f gpsd | tr '\n' ' ')
        echo "  ✓ GPSD processes running: $gpsd_pids"
        changes_found=true
    else
        echo "  ⚠ No GPSD processes found"
    fi
    echo
    
    # Check scheduled tasks
    print_color $CYAN "=== Scheduled Tasks ==="
    local post_reboot_script="/tmp/post-reboot-gps.sh"
    if [ -f "$post_reboot_script" ]; then
        echo "  ✓ Post-reboot script found: $post_reboot_script"
        changes_found=true
    fi
    
    local cron_entries=$(sudo crontab -l 2>/dev/null | grep -i gps)
    if [ -n "$cron_entries" ]; then
        echo "  ✓ GPS-related cron entries:"
        echo "$cron_entries" | sed 's/^/    /'
        changes_found=true
    else
        echo "  ⚠ No GPS-related cron entries found"
    fi
    echo
    
    # Check serial devices
    print_color $CYAN "=== Serial Devices ==="
    if [ -e /dev/serial0 ]; then
        echo "  ✓ /dev/serial0 exists -> $(readlink /dev/serial0 2>/dev/null || echo 'direct device')"
    else
        echo "  ⚠ /dev/serial0 not found"
    fi
    
    if [ -e /dev/serial1 ]; then
        echo "  ✓ /dev/serial1 exists -> $(readlink /dev/serial1 2>/dev/null || echo 'direct device')"
    fi
    echo
    
    return $([ "$changes_found" = true ] && echo 0 || echo 1)
}

# Function to create backup of current state
backup_current_state() {
    if [ "$DRY_RUN" = true ]; then
        print_status "DRY RUN: Would create backup of current configuration"
        return 0
    fi
    
    print_status "Creating backup of current state..."
    
    local backup_dir="/tmp/gpsberry-uninstall-backup-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup configuration files
    for file in /boot/config.txt /boot/cmdline.txt; do
        if [ -f "$file" ]; then
            cp "$file" "$backup_dir/" && print_debug "Backed up: $file"
        fi
    done
    
    # Backup crontab
    sudo crontab -l > "$backup_dir/crontab.backup" 2>/dev/null && print_debug "Backed up: crontab"
    
    # Backup package list
    dpkg -l | grep -E "(gpsd|minicom|screen|python3-gps)" > "$backup_dir/gps-packages.list" 2>/dev/null
    
    # Backup service states
    {
        echo "GPSD active: $(systemctl is-active gpsd 2>/dev/null)"
        echo "GPSD enabled: $(systemctl is-enabled gpsd 2>/dev/null)"
    } > "$backup_dir/service-states.txt"
    
    print_success "Current state backed up to: $backup_dir"
}

# Function to stop GPS services
stop_gps_services() {
    print_status "Stopping GPS services..."
    
    if $DRY_RUN; then
        print_status "DRY RUN: Would stop GPS services"
        return 0
    fi
    
    # Stop GPSD service
    if systemctl is-active gpsd >/dev/null 2>&1; then
        print_status "Stopping GPSD service..."
        if sudo systemctl stop gpsd; then
            print_success "GPSD service stopped"
        else
            print_warning "Failed to stop GPSD service"
        fi
    fi
    
    # Disable GPSD service
    if systemctl is-enabled gpsd >/dev/null 2>&1; then
        print_status "Disabling GPSD service..."
        if sudo systemctl disable gpsd; then
            print_success "GPSD service disabled"
        else
            print_warning "Failed to disable GPSD service"
        fi
    fi
    
    # Kill any remaining GPSD processes
    local gpsd_pids=$(pgrep -f gpsd)
    if [ -n "$gpsd_pids" ]; then
        print_status "Terminating remaining GPSD processes: $gpsd_pids"
        sudo pkill -f gpsd && print_success "GPSD processes terminated"
    fi
}

# Function to remove GPS packages
remove_gps_packages() {
    if [ "$KEEP_PACKAGES" = true ]; then
        print_status "Keeping packages as requested (--keep-packages)"
        return 0
    fi
    
    print_status "Removing GPS packages and tools..."
    
    local packages_to_remove="gpsd gpsd-clients python3-gps"
    local optional_packages="minicom screen"
    
    if $DRY_RUN; then
        print_status "DRY RUN: Would remove packages: $packages_to_remove"
        print_status "DRY RUN: Would optionally remove: $optional_packages"
        return 0
    fi
    
    # Remove core GPS packages
    local installed_core=""
    for pkg in $packages_to_remove; do
        if dpkg -l | grep -q "^ii.*$pkg "; then
            installed_core="$installed_core $pkg"
        fi
    done
    
    if [ -n "$installed_core" ]; then
        print_status "Removing core GPS packages:$installed_core"
        if sudo apt-get remove --purge $installed_core -y; then
            print_success "Core GPS packages removed"
        else
            print_error "Failed to remove some core GPS packages"
        fi
    else
        print_status "No core GPS packages found to remove"
    fi
    
    # Handle optional packages
    local installed_optional=""
    for pkg in $optional_packages; do
        if dpkg -l | grep -q "^ii.*$pkg "; then
            installed_optional="$installed_optional $pkg"
        fi
    done
    
    if [ -n "$installed_optional" ]; then
        if [ "$FORCE_REMOVE" = true ] || ask_yes_no "Remove optional tools ($installed_optional)?" "n"; then
            print_status "Removing optional packages:$installed_optional"
            sudo apt-get remove $installed_optional -y
        else
            print_status "Keeping optional packages:$installed_optional"
        fi
    fi
    
    # Clean up
    print_status "Cleaning up package cache..."
    sudo apt-get autoremove -y
    sudo apt-get autoclean
}

# Function to restore configuration from backups
restore_configurations() {
    if [ "$RESTORE_BACKUPS" = false ]; then
        print_status "Skipping backup restoration (--no-restore-backups)"
        return 0
    fi
    
    print_status "Restoring configuration files from backups..."
    
    if $DRY_RUN; then
        print_status "DRY RUN: Would restore configuration backups"
        find_config_backups
        return 0
    fi
    
    local restored_any=false
    
    # Restore config.txt
    local latest_config_backup=$(ls -t /boot/config.txt.backup.* 2>/dev/null | head -1)
    if [ -n "$latest_config_backup" ]; then
        print_status "Restoring /boot/config.txt from $latest_config_backup"
        if sudo cp "$latest_config_backup" /boot/config.txt; then
            print_success "config.txt restored"
            restored_any=true
        else
            print_error "Failed to restore config.txt"
        fi
    else
        print_warning "No config.txt backup found"
        # Manual UART disable
        if grep -q "enable_uart=1" /boot/config.txt; then
            if ask_yes_no "Manually disable UART in config.txt?" "y"; then
                sudo sed -i 's/^enable_uart=1/#enable_uart=1  # disabled by GPSBerry uninstall/' /boot/config.txt
                print_success "UART disabled in config.txt"
                restored_any=true
            fi
        fi
    fi
    
    # Restore cmdline.txt
    local latest_cmdline_backup=$(ls -t /boot/cmdline.txt.backup.* 2>/dev/null | head -1)
    if [ -n "$latest_cmdline_backup" ]; then
        print_status "Restoring /boot/cmdline.txt from $latest_cmdline_backup"
        if sudo cp "$latest_cmdline_backup" /boot/cmdline.txt; then
            print_success "cmdline.txt restored"
            restored_any=true
        else
            print_error "Failed to restore cmdline.txt"
        fi
    else
        print_warning "No cmdline.txt backup found"
        # Check if we need to re-enable serial console
        if ! grep -q "console=serial" /boot/cmdline.txt; then
            if ask_yes_no "Re-enable serial console in cmdline.txt?" "n"; then
                # This is complex and risky, so we'll skip automatic restoration
                print_warning "Manual cmdline.txt restoration required"
                print_status "Consider running: sudo raspi-config nonint do_serial 1"
            fi
        fi
    fi
    
    # Restore crontab
    local latest_cron_backup=$(ls -t /tmp/crontab.backup.* 2>/dev/null | head -1)
    if [ -n "$latest_cron_backup" ]; then
        print_status "Restoring crontab from $latest_cron_backup"
        if sudo crontab "$latest_cron_backup"; then
            print_success "Crontab restored"
            restored_any=true
        else
            print_error "Failed to restore crontab"
        fi
    else
        # Remove GPS-related cron entries
        if sudo crontab -l 2>/dev/null | grep -q "post-reboot-gps"; then
            print_status "Removing GPS-related cron entries..."
            sudo crontab -l 2>/dev/null | grep -v "post-reboot-gps" | sudo crontab -
            print_success "GPS cron entries removed"
            restored_any=true
        fi
    fi
    
    if [ "$restored_any" = true ]; then
        print_success "Configuration restoration completed"
    else
        print_warning "No configurations were restored"
    fi
}

# Function to clean up temporary files
cleanup_files() {
    print_status "Cleaning up temporary files and scripts..."
    
    local files_to_remove=(
        "/tmp/post-reboot-gps.sh"
        "/tmp/gpsberry-install.log"
        "/tmp/gps-test.log"
    )
    
    if $DRY_RUN; then
        print_status "DRY RUN: Would remove temporary files:"
        printf '  %s\n' "${files_to_remove[@]}"
        return 0
    fi
    
    local removed_count=0
    for file in "${files_to_remove[@]}"; do
        if [ -f "$file" ]; then
            if sudo rm -f "$file"; then
                print_debug "Removed: $file"
                ((removed_count++))
            else
                print_warning "Failed to remove: $file"
            fi
        fi
    done
    
    # Clean up old backup files (older than 30 days)
    if [ "$removed_count" -gt 0 ]; then
        print_success "Removed $removed_count temporary file(s)"
    fi
    
    # Optionally clean up old backups
    if ask_yes_no "Remove old configuration backups (>30 days)?" "n"; then
        find /boot /tmp -name "*.backup.*" -mtime +30 -exec sudo rm -f {} \; 2>/dev/null
        print_status "Old backup files cleaned up"
    fi
}

# Function to show uninstall summary
show_uninstall_summary() {
    print_color $CYAN "=================================================="
    print_color $CYAN "            Uninstall Summary"
    print_color $CYAN "=================================================="
    echo
    
    print_color $GREEN "✓ Actions completed:"
    if [ "$KEEP_PACKAGES" = false ]; then
        echo "  • GPS packages removed (gpsd, gpsd-clients, etc.)"
    else
        echo "  • GPS packages kept (--keep-packages specified)"
    fi
    
    if [ "$KEEP_CONFIGS" = false ]; then
        if [ "$RESTORE_BACKUPS" = true ]; then
            echo "  • Configuration files restored from backups"
        else
            echo "  • Configuration changes reverted"
        fi
    else
        echo "  • Configurations kept (--keep-configs specified)"
    fi
    
    echo "  • GPS services stopped and disabled"
    echo "  • Temporary files cleaned up"
    echo "  • Scheduled tasks removed"
    echo
    
    if [ "$DRY_RUN" = false ]; then
        print_color $YELLOW "⚠  Important Notes:"
        echo "  • A reboot is recommended to ensure all changes take effect"
        echo "  • Serial console behavior may have changed"
        echo "  • Check /boot/config.txt and /boot/cmdline.txt if needed"
        echo
        
        print_color $BLUE "📋 To verify uninstall:"
        echo "  • Check packages: dpkg -l | grep -E '(gpsd|minicom|screen)'"
        echo "  • Check UART: grep uart /boot/config.txt"
        echo "  • Check serial: ls -la /dev/serial*"
        echo "  • Check services: systemctl status gpsd"
        echo
    fi
    
    print_color $CYAN "📄 Log file: $LOG_FILE"
    echo
}

# Function to handle cleanup on exit
cleanup_on_exit() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        print_error "Uninstall failed with exit code $exit_code"
        print_status "Check log file for details: $LOG_FILE"
    fi
}

# Set trap for cleanup
trap cleanup_on_exit EXIT

# Parse command line arguments
LIST_CHANGES=false
BACKUP_CURRENT=false
RESTORE_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -n|--non-interactive)
            INTERACTIVE=false
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -l|--log)
            LOG_FILE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --keep-packages)
            KEEP_PACKAGES=true
            shift
            ;;
        --keep-configs)
            KEEP_CONFIGS=true
            shift
            ;;
        --no-restore-backups)
            RESTORE_BACKUPS=false
            shift
            ;;
        --force)
            FORCE_REMOVE=true
            shift
            ;;
        --list-changes)
            LIST_CHANGES=true
            shift
            ;;
        --backup-current)
            BACKUP_CURRENT=true
            shift
            ;;
        --restore-only)
            RESTORE_ONLY=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main uninstall function
main() {
    # Initialize log file
    echo "GPSBerry Uninstall Log - $(date)" > "$LOG_FILE"
    
    # Show script header
    print_color $CYAN "=================================================="
    print_color $CYAN "          GPSBerry Uninstall Script"
    print_color $CYAN "=================================================="
    echo
    
    if [ "$INTERACTIVE" = false ]; then
        print_status "Running in NON-INTERACTIVE mode"
    fi
    
    if $DRY_RUN; then
        print_warning "DRY RUN mode - no changes will be made"
    fi
    echo
    
    # Handle special modes
    if [ "$LIST_CHANGES" = true ]; then
        analyze_current_state
        find_config_backups
        exit 0
    fi
    
    # Analyze current state
    analyze_current_state
    installation_found=$?
    
    if [ $installation_found -ne 0 ] && [ "$FORCE_REMOVE" = false ]; then
        print_warning "No GPSBerry installation detected"
        if ! ask_yes_no "Continue with uninstall anyway?" "n"; then
            print_status "Uninstall cancelled"
            exit 0
        fi
    fi
    
    # Find available backups
    find_config_backups
    backup_count=$?
    
    # Show confirmation
    if [ "$INTERACTIVE" = true ] && [ "$FORCE_REMOVE" = false ]; then
        echo
        print_color $YELLOW "This will:"
        if [ "$KEEP_PACKAGES" = false ]; then
            echo "  • Remove GPS packages and dependencies"
        fi
        if [ "$KEEP_CONFIGS" = false ]; then
            echo "  • Restore serial/UART configuration"
        fi
        echo "  • Stop and disable GPS services"
        echo "  • Clean up temporary files and scheduled tasks"
        echo
        
        if ! ask_yes_no "Proceed with uninstall?" "n"; then
            print_status "Uninstall cancelled"
            exit 0
        fi
    fi
    
    # Create backup if requested
    if [ "$BACKUP_CURRENT" = true ]; then
        backup_current_state
    fi
    
    # Execute uninstall steps
    if [ "$RESTORE_ONLY" = false ]; then
        stop_gps_services
        remove_gps_packages
        cleanup_files
    fi
    
    if [ "$KEEP_CONFIGS" = false ]; then
        restore_configurations
    fi
    
    show_uninstall_summary
    
    if [ "$DRY_RUN" = false ] && [ "$INTERACTIVE" = true ]; then
        if ask_yes_no "Reboot now to complete uninstall?" "n"; then
            print_status "Rebooting in 5 seconds... (Ctrl+C to cancel)"
            for i in {5..1}; do
                echo -n "$i... "
                sleep 1
            done
            echo
            print_status "Rebooting now..."
            sudo reboot
        else
            print_warning "Manual reboot recommended to complete uninstall"
            print_status "Run: sudo reboot"
        fi
    fi
}

# Check if running as root/sudo
if [ "$EUID" -ne 0 ] && [ "$DRY_RUN" = false ]; then
    print_error "This script must be run as root or with sudo privileges"
    print_status "Try: sudo $0 $*"
    exit 1
fi

# Run main function
main "$@"
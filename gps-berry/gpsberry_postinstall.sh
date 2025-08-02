#!/bin/bash

# Simple script to copy the GPSBerry uninstall script to /usr/local/bin/gps-berry
# Usage: Run this script as root or with sudo privileges.

INSTALL_DIR="/usr/local/bin/gps-berry"
UNINSTALL_SCRIPT="gpsberry-uninstall.sh"
TEST_SCRIPT="post-reboot.sh"
TEST_SCRIPT_NEW_NAME="gpsberry-test.sh"

echo "Copying GPSBerry scripts to system location..."

# Check if scripts exist
if [ ! -f "$UNINSTALL_SCRIPT" ]; then
    echo "Error: $UNINSTALL_SCRIPT not found in current directory"
    exit 1
fi

if [ ! -f "$TEST_SCRIPT" ]; then
    echo "Error: $TEST_SCRIPT not found in current directory"
    exit 1
fi

# Create directory if it doesn't exist
if [ ! -d "$INSTALL_DIR" ]; then
    echo "Creating directory: $INSTALL_DIR"
    sudo mkdir -p "$INSTALL_DIR"
fi

# Copy the scripts
echo "Copying $UNINSTALL_SCRIPT to $INSTALL_DIR/"
sudo cp "$UNINSTALL_SCRIPT" "$INSTALL_DIR/"

echo "Copying $TEST_SCRIPT to $INSTALL_DIR/$TEST_SCRIPT_NEW_NAME"
sudo cp "$TEST_SCRIPT" "$INSTALL_DIR/$TEST_SCRIPT_NEW_NAME"

# Make them executable
sudo chmod +x "$INSTALL_DIR/$UNINSTALL_SCRIPT"
sudo chmod +x "$INSTALL_DIR/$TEST_SCRIPT_NEW_NAME"

# Create start menu shortcut for easy GUI access
APPLICATIONS_DIR="/usr/share/applications"
SHORTCUT_FILE="$APPLICATIONS_DIR/gpsberry-tools.desktop"

echo "Creating start menu shortcut for easy access..."

# Create the desktop entry
sudo tee "$SHORTCUT_FILE" > /dev/null << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=GPSBerry Tools
Comment=Access GPSBerry test and uninstall tools
Exec=lxterminal --title="GPSBerry Tools" --command="bash -c 'echo \"GPSBerry Tools Menu\"; echo \"==================\"; echo \"1. Run GPS Test: sudo $INSTALL_DIR/$TEST_SCRIPT_NEW_NAME\"; echo \"2. Uninstall GPSBerry: sudo $INSTALL_DIR/$UNINSTALL_SCRIPT\"; echo \"\"; echo \"Choose an option or press Ctrl+C to exit\"; read -p \"Enter choice (1 or 2): \" choice; case \$choice in 1) sudo $INSTALL_DIR/$TEST_SCRIPT_NEW_NAME;; 2) sudo $INSTALL_DIR/$UNINSTALL_SCRIPT;; *) echo \"Invalid choice\";; esac; read -p \"Press Enter to close...\"'"
Icon=utilities-terminal
Terminal=false
Categories=System;
EOF

# Make the start menu shortcut executable
sudo chmod +x "$SHORTCUT_FILE"

echo "✓ Done! Scripts copied to $INSTALL_DIR/"
echo "  - Uninstall script: $INSTALL_DIR/$UNINSTALL_SCRIPT"
echo "  - Test script: $INSTALL_DIR/$TEST_SCRIPT_NEW_NAME"
echo ""
echo "✓ Start menu shortcut created: $SHORTCUT_FILE"
echo ""
echo "You can now:"
echo "  1. Find 'GPSBerry Tools' in the Applications menu (System category)"
echo "  2. Or run manually:"
echo "     - Test GPS: sudo $INSTALL_DIR/$TEST_SCRIPT_NEW_NAME"
echo "     - Uninstall: sudo $INSTALL_DIR/$UNINSTALL_SCRIPT"
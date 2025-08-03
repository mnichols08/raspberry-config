# Raspberry Pi Configuration - Essentials

This directory contains essential setup scripts and utilities for the Raspberry Pi configuration system.

## Files

### `install_essentials.sh`
The essentials setup script that handles initial system preparation:
- Installs essential packages (git, curl, wget, etc.)
- Helps create the `pi-config.conf` configuration file
- Sets up git configuration
- Creates necessary directories
- Prepares the system for the main installation

**Usage:**
```bash
sudo ./install_essentials.sh                    # Interactive setup
sudo ./install_essentials.sh --non-interactive  # Use defaults
sudo ./install_essentials.sh --config-dir /home/pi  # Custom config location
```

### `utils.sh`
Utility functions library used by all installation scripts:
- Colored output functions
- Configuration file loading
- Git repository management
- Package installation helpers
- Logging functions
- Permission checking
- Directory creation helpers

This file is sourced by other scripts to provide common functionality.

## Configuration File

The essentials setup creates a `pi-config.conf` file (default location: `/etc/pi-config.conf`) with the following structure:

```bash
# System Configuration
hostname=raspberrypi
pi_password=your_password

# Network Configuration
wifi_ssid=Your_WiFi_SSID
wifi_password=your_wifi_password

# Installation Configuration
temp_dir=/var/tmp/raspberry-config
repo_url=https://github.com/mnichols08/raspberry-config.git

# Component Installation (true/false)
install_theme=true
install_x735=true
install_gps=true

# Installation Behavior
interactive_mode=true
auto_reboot=true
cleanup_temp=true
```

## Workflow

1. **First Run**: Execute `install_essentials.sh` to set up the configuration file and prepare the system
2. **Main Installation**: Run the main `install.sh` script, which will automatically use the configuration
3. **Individual Components**: Run specific component installers as needed

## Security

- Configuration files are created with 600 permissions (owner read/write only)
- Passwords are hidden in output messages
- All operations require sudo/root privileges
- Logs are created in `/var/log/raspberry-config/`

## Examples

### Complete First-Time Setup
```bash
# 1. Run essentials setup (interactive)
sudo ./essentials/install_essentials.sh

# 2. Run main installation using the configuration
sudo ./install.sh
```

### Non-Interactive Setup
```bash
# 1. Set up essentials with defaults
sudo ./essentials/install_essentials.sh --non-interactive

# 2. Run main installation non-interactively
sudo ./install.sh --non-interactive
```

### Custom Configuration
```bash
# 1. Set up essentials with custom config location
sudo ./essentials/install_essentials.sh --config-dir /home/pi

# 2. Run main installation with the custom config
sudo ./install.sh --config /home/pi/pi-config.conf
```

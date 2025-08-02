# GeekWorm X735 Power Management Board Scripts

This repository contain### Non-Interactiv### Installation Options

```bash
# Show help
sudo ./x735_install.sh --help

# Non-interactive mode (alias) - useful for automation
sudo ./x735_install.sh -n
```

### Integration with Larger Scripts

If you're building a comprehensive Raspberry Pi setup script, you can integrate the X735 installation like this:

```bash
#!/bin/bash
# Example: Part of a larger system configuration script

# ... other system setup tasks ...

# Install X735 power management (non-interactive)
if [[ -d "x735" ]]; then
    echo "Installing X735 Power Management Board..."
    cd x735
    sudo ./x735_install.sh --non-interactive
    cd ..
else
    echo "X735 directory not found, skipping X735 installation"
fi

# ... continue with other setup tasks ...
```ation

For automated deployments, larger system configuration scripts, or unattended installations:

```bash
# Install without prompts and auto-reboot
sudo ./x735_install.sh --non-interactive
```

**Note**: This mode is particularly useful when the X735 installation is part of a larger automated Raspberry Pi setup process.lation, management, and utility scripts for the GeekWorm X735 Power Management Board for Raspberry Pi.

## Table of Contents

- [Overview](#overview)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Scripts and Components](#scripts-and-components)
- [Uninstallation](#uninstallation)
- [Troubleshooting](#troubleshooting)
- [Hardware Compatibility](#hardware-compatibility)
- [License](#license)

## Overview

The X735 Power Management Board provides intelligent power management, fan control, and safe shutdown capabilities for Raspberry Pi systems. This script collection automates the installation and configuration of all necessary components to fully utilize the X735 board's features.

### Key Features

- **Automatic Fan Control**: Temperature-based PWM fan speed control
- **Power Management**: Hardware-level power button functionality with safe shutdown
- **Safe Shutdown**: Software-triggered safe shutdown with configurable timing
- **System Integration**: Systemd services for automatic startup and management
- **Desktop Integration**: GUI menu entries for easy access to utilities
- **Hardware PWM**: Uses hardware PWM for precise fan control
- **Modern GPIO Interface**: Uses `gpiod` instead of deprecated interfaces

## Requirements

### Hardware
- Raspberry Pi (compatible models: Pi 2B, 3B, 3B+, 4B) (Raspberry Pi 5 requires script modification)
- GeekWorm X735 Power Management Board (V2.1, V2.5, V3.0)
- MicroSD card with Raspberry Pi OS

### Software
- Raspberry Pi OS (Debian-based)
- Root/sudo privileges
- Git (for submodule updates)
- Internet connection (for package installation)

### Dependencies (automatically installed)
- `gpiod` - Modern GPIO control interface
- `python3-rpi.gpio` - Python GPIO library

## Installation

### About the Installation Script

The X735 installation script (`x735_install.sh`) is designed to be modular and can be used in different ways:

- **Standalone Installation**: Run the script directly for X735-only setup
- **Part of Larger Automation**: Typically integrated into comprehensive Raspberry Pi configuration scripts that handle multiple components (networking, security, other hardware, etc.)

Most users will encounter this script as part of a larger system setup workflow, but it can absolutely be run independently if you only need X735 functionality.

### Quick Installation

For most users, the easiest installation method:

```bash
# Clone or download the repository
git clone https://github.com/mnichols08/raspberry-config

# Navigate to the x735 directory
cd raspberry-config/x735

# Run the X735 installation script directly
sudo ./x735_install.sh
```

### Non-Interactive Installation

For automated deployments or scripts:

```bash
# Install without prompts and auto-reboot
sudo ./x735/x735_install.sh --non-interactive
```

### Installation Options

```bash
# Show help
sudo ./x735/x735_install.sh --help

# Non-interactive mode (alias)
sudo ./x735/x735_install.sh -n
```

### What the Installation Does

1. **System Checks**: Verifies Raspberry Pi hardware and privileges
2. **Config Backup**: Creates timestamped backup of `/boot/config.txt`
3. **PWM Overlay**: Adds `dtoverlay=pwm-2chan,pin2=13,func2=4` to config.txt
4. **Package Installation**: Installs required system packages
5. **Service Installation**: Sets up systemd services for fan and power management
6. **Utility Installation**: Installs command-line utilities and scripts
7. **Desktop Integration**: Creates application menu entries
8. **Verification**: Runs post-installation checks

## Usage

### Command-Line Utilities

After installation, the following commands are available:

#### xSoft - Main X735 Utility
```bash
# Safe shutdown with default timing (20 seconds)
xSoft 0 20

# Safe shutdown with custom timing
xSoft <gpio_chip> <button_pin>
```

#### x735off - Quick Shutdown
```bash
# Safe shutdown the X735 board and Raspberry Pi
x735off
```

#### Fan Control Scripts
```bash
# Manual fan control (located in /usr/local/bin/x735/)
python3 /usr/local/bin/x735/pwm_fan_control.py

# Read current fan speed
python3 /usr/local/bin/x735/read_fan_speed.py
```

### Desktop Integration

After installation, X735 tools are available in the application menu:

- **Applications → System Tools → X735 Tools**
- Individual shortcuts for each utility
- Terminal-based interfaces with helpful prompts

### Service Management

The installation creates two systemd services:

#### Fan Control Service
```bash
# Check fan service status
sudo systemctl status x735-fan

# Start/stop fan service
sudo systemctl start x735-fan
sudo systemctl stop x735-fan

# Enable/disable auto-start
sudo systemctl enable x735-fan
sudo systemctl disable x735-fan
```

#### Power Management Service
```bash
# Check power service status
sudo systemctl status x735-pwr

# Start/stop power service
sudo systemctl start x735-pwr
sudo systemctl stop x735-pwr

# Enable/disable auto-start
sudo systemctl enable x735-pwr
sudo systemctl disable x735-pwr
```

### Temperature-Based Fan Control

The fan control system automatically adjusts fan speed based on CPU temperature:

| Temperature Range | Fan Speed (Duty Cycle) |
|-------------------|------------------------|
| 75°C and above    | 100% (Maximum)         |
| 70°C - 74°C       | 80%                    |
| 60°C - 69°C       | 70%                    |
| 50°C - 59°C       | 50%                    |
| 40°C - 49°C       | 45%                    |
| 25°C - 39°C       | 40%                    |
| Below 25°C        | 0% (Off)               |

### Power Button Functionality

The X735 board provides hardware power button functionality:

- **Short Press (200-600ms)**: Triggers system reboot
- **Long Press (>600ms)**: Triggers safe system shutdown
- **Button Release**: Action is executed after button release

## Scripts and Components

### Main Installation Script

#### `x735_install.sh`
Interactive installation script with comprehensive error checking and validation.

**Features:**
- Command-line argument parsing
- Non-interactive mode support
- Colored output with status indicators
- Automatic backup creation
- Service verification
- Desktop integration setup

### Core Utility Scripts

#### `xSoft.sh`
Safe shutdown utility using modern GPIO interface.
```bash
# Usage: xSoft.sh <gpio_chip> <button_pin>
# Example: xSoft.sh 0 20
```

#### `xPWR.sh`
Power management daemon for hardware button monitoring.
```bash
# Usage: xPWR.sh <pwm_chip> <shutdown_pin> <boot_pin>
# Example: xPWR.sh 0 5 12
```

### Fan Control Scripts

#### `x735-fan.sh`
Advanced PWM-based fan control with configurable parameters.

**Configuration Variables:**
- `PWM_CHANNEL=1` - PWM channel (0 or 1)
- `PWM_HERTZ=2000` - PWM frequency
- `SLEEP_INTERVAL=5` - Temperature check interval
- `SHOW_DEBUG=0` - Debug output (0=off, 1=on)

#### `pwm_fan_control.py`
Python-based fan control with temperature thresholds.

**Features:**
- Real-time temperature monitoring
- Configurable duty cycle levels
- RPi.GPIO library integration

#### `read_fan_speed.py`
Fan speed monitoring utility.

**Features:**
- Real-time RPM measurement
- Tachometer signal processing
- Continuous monitoring with keyboard interrupt handling

### Service Files

#### `x735-fan.service`
Systemd service file for fan control daemon.

#### `x735-pwr.service`
Systemd service file for power management daemon.

### Installation Helper Scripts

#### `install-fan-service.sh`
Installs and configures the fan control service.

#### `install-pwr-service.sh`
Installs and configures the power management service.

#### `install-sss.sh`
Installs the soft shutdown script (safe shutdown service).

## Uninstallation

### Complete Removal

To completely remove all X735 components:

```bash
# Run the uninstall script
sudo /usr/local/bin/x735/uninstall.sh
```

### What Uninstallation Removes

1. **System Services**: Stops and removes x735-fan and x735-pwr services
2. **Service Files**: Removes systemd service files
3. **Utilities**: Removes xSoft utility and symlinks
4. **Scripts**: Removes x735off power-down script
5. **Directory**: Removes /usr/local/bin/x735/ directory and contents
6. **Config Changes**: Removes PWM overlay from config.txt
7. **Desktop Integration**: Removes start menu entries
8. **Temporary Files**: Cleans up installation directories

### Post-Uninstallation

After uninstallation:
- Reboot is recommended to disable PWM overlay
- X735 board will no longer be software-managed
- Hardware functionality (manual buttons) remains available

## Troubleshooting

### Common Issues

#### Installation Fails with "Not a Raspberry Pi"
```bash
# Check if you're on a Raspberry Pi
cat /proc/device-tree/model
```

#### PWM Overlay Not Working
```bash
# Check if overlay is in config.txt
grep -i pwm /boot/config.txt

# Verify PWM hardware availability
ls -la /sys/class/pwm/
```

#### Services Not Starting
```bash
# Check service status
sudo systemctl status x735-fan
sudo systemctl status x735-pwr

# View service logs
sudo journalctl -u x735-fan
sudo journalctl -u x735-pwr
```

#### Fan Not Responding
```bash
# Check PWM permissions
ls -la /sys/class/pwm/pwmchip0/

# Test PWM manually
echo 1 > /sys/class/pwm/pwmchip0/export
echo 2000 > /sys/class/pwm/pwmchip0/pwm1/period
echo 1000 > /sys/class/pwm/pwmchip0/pwm1/duty_cycle
echo 1 > /sys/class/pwm/pwmchip0/pwm1/enable
```

#### Temperature Readings Incorrect
```bash
# Check thermal zone
cat /sys/class/thermal/thermal_zone0/temp

# Manual temperature calculation
awk '{print $1/1000}' /sys/class/thermal/thermal_zone0/temp
```

### Log Files

Check these locations for troubleshooting:

```bash
# System logs
sudo journalctl -xe

# Service-specific logs
sudo journalctl -u x735-fan -f
sudo journalctl -u x735-pwr -f

# Installation logs (if using script output redirection)
tail -f /var/log/x735-install.log
```

### Permission Issues

If you encounter permission issues:

```bash
# Ensure proper ownership
sudo chown root:root /usr/local/bin/x735/*
sudo chmod +x /usr/local/bin/x735/*

# Check GPIO group membership
groups $USER
sudo usermod -a -G gpio $USER
```

## Hardware Compatibility

### Raspberry Pi Models

| Model | GPIO Chip | Button Pin | Power Pins | Status |
|-------|-----------|------------|------------|---------|
| Pi 2B | 0 | 20 | 5, 12 | ✅ Supported |
| Pi 3B/3B+ | 0 | 20 | 5, 12 | ✅ Supported |
| Pi 4B | 0 | 20 | 5, 12 | ✅ Supported |
| Pi 5 | 4 | 20 | 5, 12 | ✅ Supported* |

*For Raspberry Pi 5, the installation automatically adjusts GPIO chip and PWM paths.

### X735 Board Versions

| Version | Features | Compatibility |
|---------|----------|---------------|
| X735 V2.1 | Basic power management | ✅ Full support |
| X735 V2.5 | Enhanced power features | ✅ Full support |
| X735 V3.0 | Latest features | ✅ Full support |

### Pin Assignments

#### Default Configuration
- **Fan PWM**: GPIO 13 (PWM1)
- **Power Button**: GPIO 20
- **Shutdown Signal**: GPIO 5
- **Boot Signal**: GPIO 12
- **Fan Tachometer**: GPIO 16

#### Raspberry Pi 5 Adjustments
For Pi 5 hardware, the following changes are automatically applied:
- GPIO chip: `4` instead of `0`
- PWM chip path: `/sys/class/pwm/pwmchip2` instead of `pwmchip0`

## Advanced Configuration

### Customizing Fan Curves

Edit `/usr/local/bin/x735/x735-fan.sh` to modify temperature thresholds:

```bash
# Example custom thresholds
if [ "$CUR_TEMP" -ge 80 ]; then
    DUTY_CYCLE=100
elif [ "$CUR_TEMP" -ge 70 ]; then
    DUTY_CYCLE=90
# ... add more ranges as needed
```

### Custom PWM Frequency

Modify the PWM frequency in `x735-fan.sh`:

```bash
# Change PWM frequency (default: 2000Hz)
PWM_HERTZ=1000
```

### Debug Mode

Enable debug output for troubleshooting:

```bash
# In x735-fan.sh
SHOW_DEBUG=1
```

### Custom Sleep Intervals

Adjust temperature check frequency:

```bash
# In x735-fan.sh (default: 5 seconds)
SLEEP_INTERVAL=10
```

## Development and Contributing

### File Structure
```
x735/
├── x735_install.sh              # Main installation script
├── bin/                         # Utility binaries
│   ├── pwm_fan_control.py
│   └── read_fan_speed.py
├── install_files/               # Installation components
│   ├── install-fan-service.sh
│   ├── install-pwr-service.sh
│   ├── install-sss.sh
│   ├── uninstall.sh
│   ├── x735-fan.service
│   ├── x735-fan.sh
│   ├── x735-pwr.service
│   ├── xPWR.sh
│   └── xSoft.sh
└── README.md                    # This file
```

### Testing

Before submitting changes:

1. Test installation on clean Raspberry Pi OS
2. Verify all services start correctly
3. Test fan control across temperature ranges
4. Verify safe shutdown functionality
5. Test uninstallation process

## License

This project includes components with various licenses:

- Installation scripts: MIT License
- X735 core scripts: GeekWorm original license
- Python utilities: MIT License

See individual files for specific license information.

## Support and Resources

### Official Resources
- **GeekWorm Wiki**: https://wiki.geekworm.com/X735-script
- **GeekWorm Support**: support@geekworm.com

### Community Resources
- GitHub Issues: Report bugs and feature requests
- Wiki Documentation: User guides and tutorials
- Community Forums: Discussion and troubleshooting

### Getting Help

When seeking support, please provide:

1. **Hardware Information**:
   ```bash
   cat /proc/device-tree/model
   uname -a
   ```

2. **Software Version**:
   ```bash
   lsb_release -a
   dpkg -l | grep -E "(gpiod|python3-rpi.gpio)"
   ```

3. **Service Status**:
   ```bash
   sudo systemctl status x735-fan x735-pwr
   ```

4. **Error Logs**:
   ```bash
   sudo journalctl -u x735-fan --no-pager
   sudo journalctl -u x735-pwr --no-pager
   ```

5. **Configuration**:
   ```bash
   grep -i pwm /boot/config.txt
   ls -la /sys/class/pwm/
   ```

---

**Note**: Always ensure your Raspberry Pi is properly shut down before making hardware connections or modifications to prevent damage to your system or the X735 board.

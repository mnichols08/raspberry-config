# GPSBerry - Raspberry Pi GPS Setup Scripts

A comprehensive set of scripts to easily install, configure, test, and manage GPS functionality on Raspberry Pi devices.

## 📋 Overview

GPSBerry provides automated tools to:
- Install and configure GPS software (GPSD) on Raspberry Pi
- Set up serial communication for GPS modules
- Test GPS functionality with multiple methods
- Provide easy GUI access to GPS tools
- Cleanly uninstall GPS configuration when needed

## 🗂️ Script Files

| Script | Purpose | Usage |
|--------|---------|-------|
| `gpsberry_install.sh` | Main installation script | `sudo ./gpsberry_install.sh` |
| `gpsberry_postinstall.sh` | Post-installation setup (runs automatically) | `sudo ./gpsberry_postinstall.sh` |
| `post-reboot.sh` | GPS testing and configuration script | `sudo ./post-reboot.sh` |
| `gpsberry_uninstall.sh` | Complete uninstallation script | `sudo ./gpsberry_uninstall.sh` |

## 🚀 Quick Start

### 1. Installation
```bash
# Run the installation (requires sudo)
sudo ./gpsberry_install.sh
```

### 2. Reboot
The installation script will prompt you to reboot. This is **required** for GPS functionality to work properly.

### 3. Access GPS Tools
After reboot, you can access GPS tools through:
- **GUI**: Applications menu → System → "GPSBerry Tools"
- **Command line**: `sudo /usr/local/bin/gps-berry/gpsberry-test.sh`

## 📖 Detailed Usage

### Installation Script (`gpsberry_install.sh`)

The main installation script that sets up your Raspberry Pi for GPS communication.

**Basic usage:**
```bash
sudo ./gpsberry_install.sh
```

**Options:**
```bash
sudo ./gpsberry_install.sh [OPTIONS]

Options:
  -h, --help              Show help message
  -n, --non-interactive   Run without user prompts (auto-confirm)
  -d, --dry-run          Preview changes without making them
  -s, --skip-update      Skip system package updates
  -v, --verbose          Enable detailed output
  -l, --log FILE         Specify custom log file
```

**What it does:**
- ✅ Verifies Raspberry Pi compatibility
- ✅ Updates system packages (optional)
- ✅ Installs GPS software (gpsd, gpsd-clients, python3-gps, minicom)
- ✅ Configures serial port (disables console, enables hardware)
- ✅ Sets up post-reboot configuration
- ✅ Creates GUI shortcuts for easy access
- ✅ Backs up all configuration files

### Testing Script (`post-reboot.sh` → `gpsberry-test.sh`)

Comprehensive GPS testing with multiple methods and tools.

**Basic usage:**
```bash
# Through GUI menu
Applications → System → GPSBerry Tools → Option 1

# Direct command line
sudo /usr/local/bin/gps-berry/gpsberry-test.sh
```

**Advanced options:**
```bash
sudo ./post-reboot.sh [OPTIONS]

Options:
  -h, --help                Show help message
  -n, --non-interactive     Run without user prompts
  -d, --dry-run            Preview actions only
  -v, --verbose            Detailed output
  -m, --method METHOD      Auto-select test method:
                             cat, minicom, screen, install-only, skip
  -t, --timeout SECONDS    Test duration (default: 10s)
  -b, --baud RATE         Baud rate (default: 9600)
  -s, --serial DEVICE     Serial device (default: /dev/serial0)
  --gpsd                  Test GPSD daemon instead of raw serial
```

**Testing methods:**
1. **Quick Test** (`cat`): Simple 10-second data capture
2. **Minicom**: Interactive terminal with GPS data
3. **Screen**: Alternative interactive terminal
4. **GPSD Test**: Test the GPS daemon directly
5. **Install Tools Only**: Just install testing tools for later use

### Uninstall Script (`gpsberry_uninstall.sh`)

Completely removes GPS configuration and restores original settings.

**Basic usage:**
```bash
# Through GUI menu
Applications → System → GPSBerry Tools → Option 2

# Direct command line
sudo /usr/local/bin/gps-berry/gpsberry-uninstall.sh
```

**Options:**
```bash
sudo ./gpsberry_uninstall.sh [OPTIONS]

Options:
  -h, --help               Show help message
  -n, --non-interactive    Run without user prompts
  -d, --dry-run           Preview changes only
  -v, --verbose           Detailed output
  --keep-packages         Don't remove GPS software packages
  --keep-configs          Don't restore configuration files
  --no-restore-backups    Don't restore from backup files
  --force                 Force removal even if no installation detected
  --list-changes          Show what would be changed and exit
```

**What it removes:**
- 🗑️ GPS software packages (gpsd, gpsd-clients, etc.)
- 🗑️ Configuration changes (restores from backups)
- 🗑️ Scheduled tasks and temporary files
- 🗑️ GUI shortcuts and installed tools
- 🗑️ Service configurations

## 🔧 Hardware Requirements

### Supported GPS Modules
- **UART/Serial GPS modules** (most common)
- **USB GPS modules** (may require different device paths)
- Any GPS module that outputs **NMEA sentences**

### Wiring for UART GPS Modules
| GPS Module | Raspberry Pi |
|------------|--------------|
| VCC        | 3.3V or 5V (check module specs) |
| GND        | GND |
| TX         | GPIO 15 (RX) |
| RX         | GPIO 14 (TX) |

**Note**: Some GPS modules use different voltage levels. Always check your module's specifications.

## 📡 Expected GPS Output

When working correctly, you should see **NMEA sentences** like:
```
$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47
$GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W*6A
$GPGSV,2,1,08,01,40,083,46,02,17,308,41,12,07,344,39,14,22,228,45*75
```

### NMEA Sentence Types
- `$GPGGA`: Global positioning system fix data
- `$GPRMC`: Recommended minimum specific GPS data
- `$GPGSV`: GPS satellites in view
- `$GPGLL`: Geographic position (latitude/longitude)

## 🐛 Troubleshooting

### No GPS Data Received

**Check hardware:**
1. Verify wiring connections
2. Ensure GPS module has power (LED indicators)
3. Check antenna connection and placement
4. Wait for GPS lock (can take 2-15 minutes outdoors)

**Check configuration:**
```bash
# Verify serial device exists
ls -la /dev/serial*

# Check UART configuration
grep uart /boot/config.txt

# Check for conflicting processes
sudo lsof /dev/serial0

# Manual test
sudo cat /dev/serial0
```

### Permission Issues
```bash
# Add user to dialout group
sudo usermod -a -G dialout $USER

# Check device permissions
ls -la /dev/serial0
```

### Different Baud Rates
Some GPS modules use different baud rates. Try:
```bash
# Test different baud rates
sudo ./post-reboot.sh --baud 4800
sudo ./post-reboot.sh --baud 38400
sudo ./post-reboot.sh --baud 115200
```

### USB GPS Modules
For USB GPS modules, use a different device:
```bash
# Find USB GPS device
ls /dev/ttyUSB*
ls /dev/ttyACM*

# Test with USB device
sudo ./post-reboot.sh --serial /dev/ttyUSB0
```

## 📁 File Locations

After installation, scripts are installed to:
- **System location**: `/usr/local/bin/gps-berry/`
- **Test script**: `/usr/local/bin/gps-berry/gpsberry-test.sh`
- **Uninstall script**: `/usr/local/bin/gps-berry/gpsberry-uninstall.sh`
- **GUI shortcut**: `/usr/share/applications/gpsberry-tools.desktop`

## 📝 Log Files

Installation and testing create log files for troubleshooting:
- **Installation log**: `/tmp/gpsberry-install.log`
- **Test log**: `/tmp/gps-test.log`

## 🔄 Configuration Backups

The scripts automatically create backups of modified files:
- `/boot/config.txt.backup.YYYYMMDD_HHMMSS`
- `/boot/cmdline.txt.backup.YYYYMMDD_HHMMSS`
- `/tmp/crontab.backup.YYYYMMDD_HHMMSS`

## 🤝 Examples

### Automated Installation
```bash
# Non-interactive installation with system updates skipped
sudo ./gpsberry_install.sh --non-interactive --skip-update
```

### Quick GPS Test
```bash
# 30-second test with cat method
sudo ./post-reboot.sh --method cat --timeout 30
```

### Test with Different Hardware
```bash
# Test USB GPS at different baud rate
sudo ./post-reboot.sh --serial /dev/ttyUSB0 --baud 4800 --method minicom
```

### Preview Uninstall
```bash
# See what would be removed without actually removing it
sudo ./gpsberry_uninstall.sh --dry-run --list-changes
```

### Partial Uninstall
```bash
# Remove software but keep configuration changes
sudo ./gpsberry_uninstall.sh --keep-configs
```

## ⚠️ Important Notes

1. **Always run scripts with `sudo`** - GPS configuration requires root privileges
2. **Reboot after installation** - Serial port changes require a restart
3. **GPS lock takes time** - Allow 2-15 minutes for initial GPS fix outdoors
4. **Backup important data** - Scripts modify system configuration files
5. **Test thoroughly** - Verify GPS functionality before deploying

## 🆘 Support

For issues or questions:
1. Check the troubleshooting section above
2. Review log files for error details
3. Verify hardware connections and compatibility
4. Test with different baud rates and methods

## 📄 License

This project is provided as-is for educational and hobbyist use. Please test thoroughly before using in production environments.

---

**Author**: Mikey Nichols  
**Version**: Enhanced GPS Setup Scripts for Raspberry Pi  
**Last Updated**: August 2025

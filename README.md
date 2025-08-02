# Raspberry Pi Configuration Suite

A comprehensive collection of scripts for setting up and configuring Raspberry Pi systems with various hardware components and customizations.

## 🏗️ Project Overview

This repository provides automated installation and configuration scripts for:
- **Initial System Setup**: Base system configuration, WiFi, users, and packages
- **Theme Customization**: Desktop wallpapers, splash screens, and visual effects
- **X735 Power Management**: GeekWorm X735 power management board support
- **GPS Functionality**: GPS module setup and testing tools

## 📁 Project Structure

```
raspberry-config/
├── install.sh                 # Main installation orchestrator
├── init/                      # Initial system setup
│   ├── init.sh               # System initialization script
│   ├── pi-config.conf.example # Configuration template
│   └── README.md             # Init-specific documentation
├── theme/                     # Desktop theming and customization
│   ├── install_theme.sh      # Theme installation script
│   ├── background/           # Wallpaper images
│   ├── videos/              # Splash screen videos
│   └── README.md            # Theme-specific documentation
├── x735/                     # X735 power management board
│   ├── x735_install.sh      # X735 installation script
│   ├── bin/                 # X735 utility scripts
│   └── README.md           # X735-specific documentation
└── gps-berry/               # GPS functionality
    ├── gpsberry_install.sh  # GPS installation script
    ├── post-reboot.sh       # GPS testing tools
    └── README.md           # GPS-specific documentation
```

## 🚀 Quick Start

### Complete Setup (Recommended)

1. **Run the installation script**:
   ```bash
   # Download and run the complete installation (interactive)
   curl -fsSL https://raw.githubusercontent.com/mnichols08/raspberry-config/master/install.sh | sudo bash
   
   # OR clone first and run locally
   git clone https://github.com/mnichols08/raspberry-config.git
   cd raspberry-config
   sudo bash install.sh
   
   # OR non-interactive installation
   sudo bash install.sh -n
   ```

   The installation script will automatically:
   - Download/clone the latest configuration files
   - Run the initial system setup (hostname, WiFi, password, etc.)
   - Install all selected components
   - Handle configuration and cleanup

### Individual Component Installation

You can also install components individually if you only need specific functionality:

```bash
# Clone the repository first
git clone https://github.com/mnichols08/raspberry-config.git
cd raspberry-config

# Initial setup only
sudo bash init/init.sh

# Theme customization only
sudo bash theme/install_theme.sh

# X735 power management only
sudo bash x735/x735_install.sh

# GPS functionality only
sudo bash gps-berry/gpsberry_install.sh
```

## 📋 Prerequisites

### System Requirements
- Raspberry Pi with Raspbian OS (Buster or newer)
- Internet connection for package downloads
- Root/sudo access
- At least 1GB free disk space

### Hardware Support
- **X735 Board**: GeekWorm X735 Power Management Board
- **GPS Module**: USB or UART GPS modules
- **Display**: For theme customization features

## ⚙️ Configuration

### Configuration File Setup

1. **Copy the example configuration**:
   ```bash
   cp init/pi-config.conf.example init/pi-config.conf
   ```

2. **Edit the configuration file**:
   ```bash
   nano init/pi-config.conf
   ```

3. **Set secure permissions**:
   ```bash
   chmod 600 init/pi-config.conf
   ```

### Configuration Options

```bash
# System Configuration
hostname=MyRaspberryPi
temp_dir=/var/tmp/raspberry-config

# User Credentials
pi_password=YourSecurePassword123

# WiFi Configuration
wifi_ssid=YourNetworkName
wifi_password=YourWiFiPassword

# Repository Configuration (optional)
repo_url=https://github.com/mnichols08/raspberry-config.git
```

## 🔧 Main Installation Script (`install.sh`)

The main installation script orchestrates all component installations.

### Usage

```bash
sudo bash install.sh [OPTIONS]
```

### Command Line Options

| Option | Description | Example |
|--------|-------------|---------|
| `-n, --non-interactive` | Run without user prompts | `sudo bash install.sh -n` |
| `-h, --help` | Show help message | `sudo bash install.sh --help` |
| `--temp-dir DIR` | Set custom temporary directory | `sudo bash install.sh --temp-dir /tmp/config` |
| `--repo-url URL` | Set custom repository URL | `sudo bash install.sh --repo-url https://github.com/user/fork.git` |
| `-c, --config FILE` | Load configuration from file | `sudo bash install.sh --config /path/to/config.conf` |
| `--hostname HOSTNAME` | Set hostname for initial setup | `sudo bash install.sh --hostname MyPi` |
| `--password PASSWORD` | Set pi user password | `sudo bash install.sh --password MySecurePass` |
| `--wifi-ssid SSID` | Set WiFi network name | `sudo bash install.sh --wifi-ssid MyNetwork` |
| `--wifi-key KEY` | Set WiFi password | `sudo bash install.sh --wifi-key MyWiFiPass` |
| `--skip-theme` | Skip theme installation | `sudo bash install.sh --skip-theme` |
| `--skip-x735` | Skip X735 installation | `sudo bash install.sh --skip-x735` |
| `--skip-gps` | Skip GPS installation | `sudo bash install.sh --skip-gps` |
| `--no-reboot` | Don't reboot after installation | `sudo bash install.sh --no-reboot` |

### Configuration Priority

The installation script uses the following priority order for settings:

1. **Command line flags** (highest priority)
2. **Configuration file values**
3. **Default values** (lowest priority)

Configuration files are searched in this order:
- `init/pi-config.conf` (relative to script)
- `/etc/pi-config.conf` (system-wide)
- `/var/tmp/raspberry-config/init/pi-config.conf` (temp directory)

## 📦 Component Details

### 🔧 Initial Setup (`init/`)

Sets up the base Raspberry Pi system including:
- System package updates
- Hostname configuration
- User password changes
- WiFi network setup
- Repository download

**Usage**:
```bash
sudo bash init/init.sh [OPTIONS]
```

See `init/README.md` for detailed documentation.

### 🎨 Theme Customization (`theme/`)

Configures desktop appearance including:
- Desktop wallpapers with multiple display modes
- OpenAuto Pro startup videos
- Desktop effects and compositing
- Window management settings

**Usage**:
```bash
sudo bash theme/install_theme.sh [OPTIONS]
```

See `theme/README.md` for detailed documentation.

### ⚡ X735 Power Management (`x735/`)

Installs support for GeekWorm X735 power management board:
- Fan control with temperature monitoring
- Safe shutdown functionality
- Power button support
- LED indicators

**Usage**:
```bash
sudo bash x735/x735_install.sh [OPTIONS]
```

See `x735/README.md` for detailed documentation.

### 🌐 GPS Functionality (`gps-berry/`)

Sets up GPS module support:
- GPSD daemon installation and configuration
- Serial communication setup
- GPS testing tools
- GUI access to GPS utilities

**Usage**:
```bash
sudo bash gps-berry/gpsberry_install.sh [OPTIONS]
```

See `gps-berry/README.md` for detailed documentation.

## 🔒 Security Considerations

### Configuration File Security

Always secure your configuration files:
```bash
# Set restrictive permissions
chmod 600 init/pi-config.conf

# Verify permissions
ls -la init/pi-config.conf
# Should show: -rw------- (600)
```

### Environment Variables

For automation, use environment variables instead of command-line arguments:
```bash
export PI_PASSWORD="YourSecurePassword"
export WIFI_PASSWORD="YourWiFiPassword"
sudo -E bash init/init.sh --non-interactive
```

### Avoiding Credential Exposure

**❌ Avoid** (credentials visible in process list):
```bash
sudo bash init/init.sh --password "secret" --wifi-key "wifipass"
```

**✅ Use instead**:
- Configuration files with secure permissions
- Environment variables
- Interactive prompts

## 🔍 Troubleshooting

### Common Issues

1. **Permission Denied**
   ```bash
   # Ensure you're using sudo for installation scripts
   sudo bash install.sh
   ```

2. **Configuration Directory Not Found**
   ```bash
   # Run the init script first
   sudo bash init/init.sh
   ```

3. **Network Issues During Installation**
   ```bash
   # Check internet connection
   ping -c 4 google.com
   
   # Update package lists
   sudo apt update
   ```

4. **Component Installation Failures**
   ```bash
   # Check installation logs
   journalctl -xe
   
   # Try installing components individually
   sudo bash theme/install_theme.sh
   ```

### Log Files

Installation logs are typically stored in:
- `/var/log/raspberry-config/`
- Individual component logs in their respective directories

### Getting Help

1. Check component-specific README files
2. Review installation logs
3. Ensure all prerequisites are met
4. Try running components individually to isolate issues

## 📚 Advanced Usage

### Automation Example

Complete automated setup for deployment:

```bash
#!/bin/bash
# automated-setup.sh

# Method 1: Using command line arguments
sudo bash install.sh \
  --non-interactive \
  --hostname "raspberrypi-$(date +%s)" \
  --password "MySecurePassword123" \
  --wifi-ssid "MyNetwork" \
  --wifi-key "MyWiFiPassword" \
  --temp-dir "/opt/pi-setup" \
  --skip-gps

# Method 2: Using environment variables (more secure)
export PI_PASSWORD="MySecurePassword123"
export WIFI_SSID="MyNetwork" 
export WIFI_PASSWORD="MyWiFiPassword"
export PI_HOSTNAME="raspberrypi-$(date +%s)"

# Download and run with environment variables
curl -fsSL https://raw.githubusercontent.com/mnichols08/raspberry-config/master/install.sh | sudo -E bash -s -- --non-interactive

echo "Automated setup complete!"
```

### Custom Component Selection

Install only specific components:

```bash
# Only theme and GPS (skip X735)
sudo bash install.sh --skip-x735

# Only X735 power management
sudo bash install.sh --skip-theme --skip-gps

# Custom temp directory with selective installation
sudo bash install.sh --temp-dir /custom/path --skip-gps --no-reboot
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test on a Raspberry Pi
5. Submit a pull request

## 📄 License

This project is open source. See individual component directories for specific license information.

## 📞 Support

For issues and questions:
1. Check the troubleshooting section above
2. Review component-specific README files
3. Open an issue on the GitHub repository

---

**Note**: Always backup your Raspberry Pi before running installation scripts, especially on production systems.

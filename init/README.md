# Raspberry Pi Initial Setup Script

An interactive script for initial configuration of fresh Raspbian Buster installations.

## Overview

The `init.sh` script provides a comprehensive initial setup for Raspberry Pi systems, including:
- System package updates
- Hostname configuration
- User password changes
- WiFi network configuration
- Repository download and preparation
- Support for both interactive and non-interactive modes

## Features

### Interactive Mode (Default)
- Prompts user for all configuration options
- Provides current/default values for reference
- Input validation for hostnames and WiFi settings
- Confirmation before proceeding
- Colored output for better readability

### Non-Interactive Mode
- Uses command-line arguments or default values
- Perfect for automation and scripting
- No user prompts or confirmations

### Security & Validation
- Hostname validation (alphanumeric + hyphens, max 63 chars)
- WiFi SSID validation (1-32 characters)
- Automatic detection of WEP vs WPA/WPA2 networks
- Password security (not displayed in prompts)
- **Environment variable support for sensitive data**
- **Configuration file support with secure permissions**
- **Multiple security methods to avoid exposing credentials**

## Security Best Practices

### Protecting Sensitive Information

**❌ Avoid (credentials visible in process list):**
```bash
sudo bash init/init.sh --password "secret" --wifi-key "wifipass"
```

**✅ Recommended approaches:**

1. **Environment Variables:**
```bash
export PI_PASSWORD="secret"
export WIFI_PASSWORD="wifipass" 
sudo -E bash init/init.sh -n
```

2. **Configuration File:**
```bash
echo "pi_password=secret" > ~/.pi-config
echo "wifi_password=wifipass" >> ~/.pi-config
chmod 600 ~/.pi-config
sudo bash init/init.sh --config ~/.pi-config -n
```

3. **Interactive Mode (prompts don't show passwords):**
```bash
sudo bash init/init.sh  # Will prompt securely
```

### File Permissions

Always secure your configuration files:
```bash
# Set restrictive permissions
chmod 600 pi-config.conf

# Verify permissions
ls -la pi-config.conf
# Should show: -rw------- (owner read/write only)
```

### Environment Variable Security

When using environment variables with sudo, use the `-E` flag to preserve them:
```bash
export WIFI_PASSWORD="secret"
sudo -E bash init/init.sh  # -E preserves environment variables
```

## Usage

### Interactive Mode
```bash
# Run with prompts for all settings
sudo bash init/init.sh

# Run with some pre-set values
sudo bash init/init.sh --hostname MyPi --password MyPassword
```

### Non-Interactive Mode
```bash
# Use all defaults
sudo bash init/init.sh --non-interactive

# Use custom values
sudo bash init/init.sh -n --hostname "RaspberryPi" --wifi-ssid "MyNetwork" --wifi-key "MyPassword"
```

### Command Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `-n, --non-interactive` | Run without user prompts | Interactive mode |
| `-c, --config FILE` | Load configuration from file | - |
| `-h, --help` | Show help message | - |
| `--hostname HOSTNAME` | Set system hostname | `Sapphire` |
| `--password PASSWORD` | Set pi user password | `Sapphire` |
| `--wifi-ssid SSID` | Set WiFi network name | `UnKnown` |
| `--wifi-key KEY` | Set WiFi password/key | `M1a2D3d4O5g6` |
| `--repo-url URL` | Set configuration repository URL | `https://github.com/mnichols08/raspberry-config.git` |
| `--temp-dir DIR` | Set temporary directory for installation files | `/var/tmp/raspberry-config` |

### Environment Variables (Secure Configuration)

For security, sensitive data can be provided via environment variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `PI_PASSWORD` | Pi user password | `export PI_PASSWORD="SecurePass123"` |
| `WIFI_SSID` | WiFi network name | `export WIFI_SSID="MyNetwork"` |
| `WIFI_PASSWORD` | WiFi password/key | `export WIFI_PASSWORD="MyWiFiPass"` |
| `REPO_URL` | Configuration repository URL | `export REPO_URL="https://..."` |
| `PI_HOSTNAME` | System hostname | `export PI_HOSTNAME="MyPi"` |
| `TEMP_DIR` | Temporary directory for installation files | `export TEMP_DIR="/tmp/pi-config"` |

### Configuration File

Create a configuration file for persistent settings:

```bash
# Copy the example configuration
cp init/pi-config.conf.example init/pi-config.conf

# Edit with your settings
nano init/pi-config.conf

# Secure the file
chmod 600 init/pi-config.conf

# Use the configuration file
sudo bash init/init.sh --config init/pi-config.conf
```

**Configuration File Format:**
```bash
# System settings
hostname=MyRaspberryPi
pi_password=YourSecurePassword

# WiFi settings  
wifi_ssid=YourNetwork
wifi_password=YourWiFiPassword

# Repository settings
repo_url=https://github.com/user/repo.git

# Installation settings
temp_dir=/var/tmp/raspberry-config
```

## WiFi Configuration

The script automatically detects the WiFi security type:

- **WEP Networks**: Detected by hex key format (10 or 26 hex characters)
- **WPA/WPA2 Networks**: All other key formats

The script configures the appropriate authentication method automatically.

## Important: Temporary Directory Configuration

The `TEMP_DIR` environment variable controls where installation files are stored and is **critical for system integration**:

- **Default**: `/var/tmp/raspberry-config`
- **Used by**: All subsequent installation scripts (`install.sh`, component scripts)
- **Why configurable**: Allows customization for different deployment scenarios

⚠️ **Important**: If you change `TEMP_DIR`, ensure all related scripts use the same path, or set it as a system-wide environment variable.

```bash
# Example: Use custom installation directory
export TEMP_DIR="/opt/pi-setup"
sudo -E bash init/init.sh -n
sudo -E bash /opt/pi-setup/install.sh
```

## What the Script Does

1. **System Updates**: Updates all packages to latest versions
2. **Hostname**: Sets the system hostname
3. **Password**: Changes the default pi user password
4. **WiFi**: Configures and connects to WiFi network
5. **Network Test**: Verifies internet connectivity
6. **Git Installation**: Installs git if not present
7. **Repository Download**: Clones the configuration repository
8. **Script Preparation**: Makes all scripts executable

## After Running

Once the initial setup is complete, you can proceed with:

```bash
# Run the main installation script
sudo bash /var/tmp/raspberry-config/install.sh

# Or run individual components
sudo bash /var/tmp/raspberry-config/theme/install_theme.sh
sudo bash /var/tmp/raspberry-config/x735/x735_install.sh
sudo bash /var/tmp/raspberry-config/gps-berry/gpsberry_install.sh
```

## Examples

### Basic Setup
```bash
# Interactive setup with prompts
sudo bash init/init.sh
```

### Using Environment Variables (Recommended for Automation)
```bash
# Set environment variables for sensitive data
export PI_PASSWORD="SecurePassword123"
export WIFI_SSID="HomeNetwork" 
export WIFI_PASSWORD="MyWiFiPassword"
export TEMP_DIR="/custom/install/path"  # Optional: change install location

# Run non-interactive setup
sudo -E bash init/init.sh --non-interactive --hostname "MyPi"
```

### Using Configuration File (Most Secure)
```bash
# Create and edit configuration file
cp init/pi-config.conf.example init/pi-config.conf
nano init/pi-config.conf
chmod 600 init/pi-config.conf

# Run with configuration file
sudo bash init/init.sh --config init/pi-config.conf --non-interactive
```

### Automated Setup (Environment Variables)
```bash
# One-liner with environment variables
PI_PASSWORD="SecurePass" WIFI_SSID="MyNet" WIFI_PASSWORD="MyPass" \
sudo -E bash init/init.sh -n --hostname "MyPiProject"
```

### Partial Configuration
```bash
# Set hostname via argument, other settings via environment or prompts
export WIFI_PASSWORD="SecureWiFiPassword"
sudo -E bash init/init.sh --hostname "DeviceName"
```

### Legacy Method (Less Secure)
```bash
# Command line arguments (visible in process list - not recommended for production)
sudo bash init/init.sh --hostname "MyPi" --password "MyPass" --wifi-ssid "Network"
```

## Error Handling

The script includes comprehensive error handling:
- Validates all input parameters
- Checks for required system components
- Verifies network connectivity
- Provides clear error messages with colored output
- Exits gracefully on errors

## Requirements

- Fresh Raspbian Buster installation
- Root privileges (script will check and prompt for sudo)
- Active internet connection (for package updates and repository download)
- WiFi hardware (for wireless configuration)

## Troubleshooting

### Common Issues

**WiFi Connection Fails**
- Check WiFi credentials
- Verify WiFi hardware is enabled
- Ensure network is in range

**Package Update Fails**
- Check internet connectivity
- Verify repository URLs are accessible
- Try running `sudo apt update` manually

**Repository Download Fails**
- Verify internet connectivity
- Check repository URL is correct
- Ensure git is installed

**Permission Errors**
- Ensure script is run with appropriate privileges
- Don't run as root user directly (use sudo when needed)

## Integration

This script is designed to work seamlessly with the main installation system:

1. **init.sh** - Initial system setup (this script)
2. **install.sh** - Main component installation
3. **Component scripts** - Individual feature installations

The init script prepares the system for the main installation process by ensuring all prerequisites are met and the configuration repository is available.

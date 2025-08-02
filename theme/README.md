# Raspberry Pi Theme Installation Script

An interactive script for configuring wallpapers and startup videos on Raspberry Pi systems with OpenAuto Pro.

## Overview

The `install_theme.sh` script provides a user-friendly interface for:
- Setting desktop wallpapers with various display modes
- Configuring OpenAuto Pro startup videos
- Configuring desktop effects and compositing
- Supporting both interactive and non-interactive (automated) installation modes

## Features

### Wallpaper Configuration
- Automatic detection of image files (JPG, JPEG, PNG, BMP, GIF)
- Interactive selection from available images
- Multiple wallpaper display modes:
  - **Center**: Center the image on screen
  - **Tile**: Repeat the image across the screen
  - **Stretch**: Stretch image to fill screen (may distort)
  - **Fit**: Scale to fit screen while maintaining aspect ratio
  - **Fill**: Scale to fill screen (may crop image)
  - **Zoom**: Zoom image to fit screen

### Startup Video Configuration
- Automatic detection of H.264 video files
- Interactive selection from available videos
- Automatic OpenAuto Pro service configuration
- Systemd service file management

### Desktop Effects Configuration
- Multiple effect presets: None, Minimal, Standard, Enhanced, Custom
- Window transparency and opacity controls
- Window shadows with configurable intensity
- Background blur effects for modern appearance
- Smooth window animations and fading
- Rounded corners support
- Performance-optimized settings for Raspberry Pi
- Automatic compositor installation and configuration

### Installation Modes
- **Interactive Mode**: Prompts user for all selections
- **Non-Interactive Mode**: Uses default settings for automated deployment

## Prerequisites

### System Requirements
- Raspberry Pi with Raspbian OS
- X11 display server
- PCManFM file manager (for wallpaper setting)
- OpenAuto Pro (for startup video functionality)

### Required Packages
```bash
sudo apt update
sudo apt install pcmanfm git picom
```

### Directory Structure
The script expects the raspberry-config repository to be available at `/var/tmp/raspberry-config/` by default, or at a custom location specified in the configuration file. The expected structure is:
```
/var/tmp/raspberry-config/  (or custom temp_dir)
└── theme/
  ├── background/
  │   ├── *.jpg, *.png, *.bmp, *.gif (wallpaper images)
  │   └── *.h264 (startup videos)
  ├── videos/
  │   └── *.h264 (startup videos)
  ├── install_theme.sh
  └── openautopro.splash.service
```

### Configuration File Support
The script supports using a configuration file to specify custom paths and settings. The configuration file should follow the same format as `pi-config.conf`:
```
# Installation Configuration
temp_dir=/custom/path/to/raspberry-config
```

## Installation

### Automatic Repository Download
If the repository is not present, the script can automatically clone it:

```bash
# The script will prompt to download if repository is missing
./install_theme.sh
```

### Manual Repository Setup
```bash
# Clone the repository manually
sudo rm -rf /var/tmp/raspberry-config
git clone https://github.com/mnichols08/raspberry-config.git /var/tmp/raspberry-config
```

## Usage

### Interactive Mode (Default)
```bash
# Run with user prompts
./install_theme.sh
```

### Non-Interactive Mode
```bash
# Run with automatic defaults
./install_theme.sh --non-interactive
# or
./install_theme.sh -y
```

### Configuration File Mode
```bash
# Use a custom configuration file
./install_theme.sh --config /path/to/pi-config.conf

# Combine with non-interactive mode
./install_theme.sh --config /path/to/pi-config.conf --non-interactive
```

### Help
```bash
# Display usage information
./install_theme.sh --help
```

## Usage Examples

### Interactive Installation
```bash
cd /var/tmp/raspberry-config/theme
chmod +x install_theme.sh
./install_theme.sh
```

The script will guide you through:
1. **Image Selection**: Choose from available wallpaper images
2. **Display Mode**: Select how the wallpaper should be displayed
3. **Video Selection**: Choose from available startup videos
4. **Desktop Effects**: Configure compositing and visual effects
5. **Confirmation**: Review and apply settings

### Automated Installation
```bash
# For automated deployment or scripts
./install_theme.sh --non-interactive
```

In non-interactive mode:
- First available image is selected
- Wallpaper mode defaults to "stretch"
- First available video is selected
- Desktop effects default to "minimal" for best performance
- No user prompts are shown

### Configuration File Usage
```bash
# Create a configuration file (or use existing pi-config.conf)
cat > my-theme-config.conf << 'EOF'
# Custom installation path
temp_dir=/home/pi/my-raspberry-config

# Other configuration options can be included but are ignored by theme script
hostname=MyPi
EOF

# Use configuration file with the theme installer
./install_theme.sh --config my-theme-config.conf

# For fully automated deployment with custom paths
./install_theme.sh --config /etc/raspberry-config/pi-config.conf --non-interactive
```

#### Configuration File Format
The theme installation script reads the `temp_dir` value from the configuration file to determine where to look for the raspberry-config repository. The configuration file uses a simple `key=value` format:

```bash
# Lines starting with # are comments
temp_dir=/custom/installation/path

# Values with spaces should be quoted
# temp_dir="/path/with spaces/raspberry-config"

# Other configuration values are ignored by the theme script
hostname=MyDevice
wifi_ssid=MyNetwork
```

#### Benefits of Using Configuration Files
- **Consistent Paths**: Use the same configuration across multiple scripts
- **Custom Locations**: Install to non-standard directories
- **Automation**: Perfect for deployment scripts and configuration management
- **Flexibility**: Different environments can use different base paths

## File Locations

### Source Files
| Component | Source Location |
|-----------|----------------|
| Images/Videos | `${temp_dir}/theme/background/` (default: `/var/tmp/raspberry-config/theme/background/`) |
| Service Template | `${temp_dir}/theme/openautopro.splash.service` (default: `/var/tmp/raspberry-config/theme/openautopro.splash.service`) |

**Note**: `${temp_dir}` refers to the value specified in the configuration file or the default `/var/tmp/raspberry-config` if no configuration file is used.

### Destination Files
| Component | Destination Location |
|-----------|---------------------|
| Wallpaper Images | `/usr/share/background/` |
| Startup Videos | `/usr/share/openautopro/` |
| Service Configuration | `/etc/systemd/system/openautopro.splash.service` |
| Compositor Configuration | `~/.config/picom/picom.conf` |
| Compositor Autostart | `~/.config/autostart/picom.desktop` |

## Configuration Details

### Wallpaper Configuration
- Uses PCManFM's `--set-wallpaper` and `--wallpaper-mode` options
- Supports standard image formats
- Applies immediately to current session
- Persists across reboots

### Video Configuration
- Copies all video files to OpenAuto Pro directory
- Updates systemd service file with selected video path
- Enables and reloads the OpenAuto Pro splash service
- Requires reboot for video changes to take effect

### Service File Management
The script modifies the OpenAuto Pro splash service by:
1. Creating a temporary copy of the service file
2. Updating the `OPENAUTO_SPLASH_VIDEOS` environment variable
3. Commenting out alternative video configurations
4. Installing the updated service file
5. Reloading systemd configuration

### Desktop Effects Configuration
The script configures desktop compositing through Picom with several preset levels:

#### Effect Levels
- **None**: Disables all effects for maximum performance
- **Minimal**: Basic window animations only
- **Standard**: Window animations plus transparency effects
- **Enhanced**: Full effects including shadows, blur, and rounded corners
- **Custom**: Interactive configuration of individual effects

#### Compositor Features
- **Window Shadows**: Configurable shadow radius, offset, and opacity
- **Transparency**: Per-application opacity settings
- **Background Blur**: Modern blur effects behind transparent windows
- **Fading Animations**: Smooth window appear/disappear effects
- **Rounded Corners**: Configurable corner radius for modern appearance
- **Performance Optimization**: Settings tuned for Raspberry Pi hardware

## Troubleshooting

### Common Issues

#### "No image files found"
**Cause**: No supported image formats in the background directory
**Solution**: 
- Verify image files are present in `${temp_dir}/theme/background/` (check your configuration file for the correct path)
- Ensure files have supported extensions (.jpg, .jpeg, .png, .bmp, .gif)
- Check file permissions
- Verify the configuration file path is correct if using `--config`

#### "Failed to set wallpaper"
**Cause**: PCManFM not installed or display issues
**Solution**:
```bash
sudo apt install pcmanfm
export DISPLAY=:0
```

#### "No h264 video files found"
**Cause**: No H.264 videos available for startup splash
**Solution**:
- Verify .h264 files exist in the background directory
- Convert videos to H.264 format if needed
- Check file permissions

#### Repository clone fails
**Cause**: Network connectivity or permission issues
**Solution**:
```bash
# Check internet connection
ping github.com

# Ensure sufficient permissions for default location
sudo rm -rf /var/tmp/raspberry-config
sudo mkdir -p /var/tmp

# Or use custom location with proper permissions
mkdir -p /home/pi/raspberry-config
# Then use: ./install_theme.sh --config /path/to/config-with-custom-temp_dir.conf
```

#### Configuration file not found
**Cause**: Invalid path specified with `--config` option
**Solution**:
```bash
# Verify the configuration file exists
ls -la /path/to/your/config.conf

# Check file format and ensure temp_dir is properly set
grep temp_dir /path/to/your/config.conf

# Use absolute paths for configuration files
./install_theme.sh --config /full/path/to/pi-config.conf
```

#### Desktop effects not working
**Cause**: Compositor not running or OpenGL issues
**Solution**:
```bash
# Check if compositor is running
ps aux | grep picom

# Restart compositor manually
pkill picom
picom --config ~/.config/picom/picom.conf --daemon

# Check OpenGL support
glxinfo | grep "direct rendering"
```

#### Poor performance with effects enabled
**Cause**: Hardware limitations or inefficient settings
**Solution**:
- Switch to "Minimal" or "None" effects preset
- Disable blur effects in custom configuration
- Reduce shadow radius and complexity
- Ensure GPU memory split is adequate: `sudo raspi-config` → Advanced → Memory Split → 128

### Debug Mode
For troubleshooting, run with verbose output:
```bash
bash -x ./install_theme.sh
```

### Log Locations
- System logs: `journalctl -u openautopro.splash.service`
- Service status: `systemctl status openautopro.splash.service`

## Advanced Usage

### Custom Installation Paths
To use a custom installation path, create a configuration file:
```bash
# Create configuration file
cat > /home/pi/my-config.conf << 'EOF'
temp_dir=/home/pi/my-raspberry-config
EOF

# Clone repository to custom location
git clone https://github.com/mnichols08/raspberry-config.git /home/pi/my-raspberry-config

# Run installer with custom configuration
cd /home/pi/my-raspberry-config/theme
./install_theme.sh --config /home/pi/my-config.conf
```

### Custom Image Directories
To use images from a different location within your installation:
```bash
# Place your custom images in the theme/background directory
mkdir -p /custom/path/raspberry-config/theme/background
cp /path/to/your/images/* /custom/path/raspberry-config/theme/background/

# Update configuration file
echo "temp_dir=/custom/path/raspberry-config" > custom-config.conf

# Run installer
./install_theme.sh --config custom-config.conf
```

### Adding New Videos
1. Place H.264 videos in the background directory
2. Run the script to automatically detect and offer them for selection

### Service Customization
The OpenAuto Pro service can be customized by editing:
- Delay timing: `OPENAUTO_DELAY_EXIT_MS` environment variable
- Service dependencies in the `[Unit]` section
- User permissions in the `[Service]` section

### Desktop Effects Customization
Manual compositor configuration can be done by editing `~/.config/picom/picom.conf`:

#### Performance Tuning
```bash
# For older Raspberry Pi models, use lightweight settings
backend = "xrender";  # Instead of "glx"
vsync = false;        # Disable if causing issues
blur-background = false;  # Disable for better performance
```

#### Custom Opacity Rules
```bash
# Add specific application opacity in picom.conf
opacity-rule = [
    "80:class_g = 'LXTerminal'",     # Terminal transparency
    "95:class_g = 'PCManFM'",        # File manager
    "100:class_g = 'firefox'"        # Keep browser opaque
];
```

#### Effect Exclusions
```bash
# Exclude specific windows from effects
shadow-exclude = [
    "class_g = 'lxpanel'",          # Exclude panel
    "window_type = 'notification'"   # Exclude notifications
];
```

## Security Considerations

- Script requires sudo privileges for:
  - Creating system directories
  - Copying files to system locations
  - Modifying systemd services
- Always review scripts before running with elevated privileges
- Verify source repository authenticity

## Contributing

To contribute improvements:
1. Fork the repository
2. Create a feature branch
3. Test changes on actual Raspberry Pi hardware
4. Submit a pull request

## License

This script is part of the raspberry-config project. Please refer to the project's main LICENSE file for terms and conditions.

## Support

For issues and questions:
- Create an issue in the GitHub repository
- Provide full error output and system information
- Include Raspberry Pi model and OS version

## Version History

- **v1.0**: Initial release with wallpaper support
- **v2.0**: Added startup video configuration
- **v2.1**: Added non-interactive mode support
- **v2.2**: Improved error handling and user feedback
- **v3.0**: Added desktop effects and compositing configuration
- **v3.1**: Added configuration file support for custom installation paths

# Raspberry Pi Theme Installation Script

An interactive script for configuring wallpapers and startup videos on Raspberry Pi systems with OpenAuto Pro.

## Overview

The `install_theme.sh` script provides a user-friendly interface for:
- Setting desktop wallpapers with various display modes
- Configuring OpenAuto Pro startup videos
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
sudo apt install pcmanfm git
```

### Directory Structure
The script expects the raspberry-config repository to be available at `/var/tmp/raspberry-config/` with the following structure:
```
/var/tmp/raspberry-config/
├── x735/
│   └── background/
│       ├── *.jpg, *.png, *.bmp, *.gif (wallpaper images)
│       └── *.h264 (startup videos)
└── theme/
    ├── install_theme.sh
    └── openautopro.splash.service
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
4. **Confirmation**: Review and apply settings

### Automated Installation
```bash
# For automated deployment or scripts
./install_theme.sh --non-interactive
```

In non-interactive mode:
- First available image is selected
- Wallpaper mode defaults to "stretch"
- First available video is selected
- No user prompts are shown

## File Locations

### Source Files
| Component | Source Location |
|-----------|----------------|
| Images/Videos | `/var/tmp/raspberry-config/x735/background/` |
| Service Template | `/var/tmp/raspberry-config/theme/openautopro.splash.service` |

### Destination Files
| Component | Destination Location |
|-----------|---------------------|
| Wallpaper Images | `/usr/share/background/` |
| Startup Videos | `/usr/share/openautopro/` |
| Service Configuration | `/etc/systemd/system/openautopro.splash.service` |

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

## Troubleshooting

### Common Issues

#### "No image files found"
**Cause**: No supported image formats in the background directory
**Solution**: 
- Verify image files are present in `/var/tmp/raspberry-config/x735/background/`
- Ensure files have supported extensions (.jpg, .jpeg, .png, .bmp, .gif)
- Check file permissions

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

# Ensure sufficient permissions
sudo rm -rf /var/tmp/raspberry-config
sudo mkdir -p /var/tmp
```

### Debug Mode
For troubleshooting, run with verbose output:
```bash
bash -x ./install_theme.sh
```

### Log Locations
- System logs: `journalctl -u openautopro.splash.service`
- Service status: `systemctl status openautopro.splash.service`

## Advanced Usage

### Custom Image Directories
To use images from a different location, modify the script variables:
```bash
# Edit the script to change source paths
BACKGROUND_SOURCE="/path/to/your/images"
```

### Adding New Videos
1. Place H.264 videos in the background directory
2. Run the script to automatically detect and offer them for selection

### Service Customization
The OpenAuto Pro service can be customized by editing:
- Delay timing: `OPENAUTO_DELAY_EXIT_MS` environment variable
- Service dependencies in the `[Unit]` section
- User permissions in the `[Service]` section

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

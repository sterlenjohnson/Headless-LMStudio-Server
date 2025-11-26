# 🤖 Running LM Studio Headless: A Systemd Guide for 24/7 LLM Service

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Linux](https://img.shields.io/badge/Linux-Compatible-green.svg)](https://www.linux.org/)
[![Systemd](https://img.shields.io/badge/Systemd-Required-blue.svg)](https://systemd.io/)

## Introduction

This guide provides a robust, generalized configuration for Debian, Fedora, and Arch-based systems to run LM Studio as a true server without a graphical interface. It covers headless execution, autostart, auto-restart, and automatic updates.

## 🎯 Why This Guide?

While LM Studio is excellent for desktop use, running it as a true server presents several challenges:

- **Existing solutions are incomplete**: Most guides assume you have a GUI or don't address auto-updates
- **Official docs are GUI-focused**: LM Studio's documentation primarily covers graphical installations
- **No comprehensive systemd integration**: Community solutions lack proper service management, auto-restart, and update mechanisms
- **Fragmented information**: Setup instructions are scattered across forums, GitHub issues, and partial blog posts

**This guide uniquely provides:**
- ✅ True headless operation (no GUI required)
- ✅ Automatic service recovery on crashes
- ✅ Automated weekly updates with zero downtime strategy
- ✅ Multi-distribution support (Debian/Ubuntu, Fedora, Arch)
- ✅ Production-ready systemd integration
- ✅ Comprehensive troubleshooting and security guidance

## ⚠️ Important Disclaimers

**Terms of Service**: LM Studio is free for both personal and work use. This guide involves automated downloads of LM Studio, which is permitted under their terms. Review [LM Studio's Terms of Service](https://lmstudio.ai/app-terms) if you have specific compliance concerns.

**Security Notice**: This setup exposes LM Studio's API server on your network. Ensure you:
- Run this on a trusted/protected network
- Consider implementing authentication via a reverse proxy (nginx/traefik)
- Use a firewall to restrict access to authorized IP addresses only
- Avoid exposing port 1234 directly to the internet without proper security measures

**Acknowledgments**: This guide was inspired by community efforts, including work by Angelo Artuso and the run.tournament.org.il project, but provides a more comprehensive and automated solution for true headless deployments.

**Testing Status**: This guide has been tested on Ubuntu 24.04, Fedora 43, and Arch Linux. Report issues via [GitHub Issues](https://github.com/sterlenjohnson/Headless-LMStudio-Server/issues).

**Resource Requirements**:
- Minimum 16GB RAM (32GB+ recommended for larger models)
- GPU with adequate VRAM for your target models (8GB+ recommended)
- At least 50GB free storage for models and updates
- x86_64 processor with AVX2 support

---

## 📦 Prerequisites: Install Dependencies

Before configuring Systemd, you need **wget** (for downloads) and **Xvfb** (Virtual Frame Buffer) to simulate a display, which is required by the Electron backend.

Execute the command corresponding to your distribution:

| Distribution | Command |
|:-------------|:--------|
| **Fedora** | `sudo dnf install wget xorg-x11-server-Xvfb` |
| **Debian/Ubuntu** | `sudo apt install wget xvfb` |
| **Arch Linux** | `sudo pacman -S wget xorg-server-xvfb` |

---

## 🚀 Quick Start

If you want to jump right in:

```bash
# 1. Clone this repository
git clone https://github.com/sterlenjohnson/Headless-LMStudio-Server.git
cd Headless-LMStudio-Server

# 2. Install dependencies (choose your distribution)
# Debian/Ubuntu:
sudo apt install wget xvfb
# Fedora:
sudo dnf install wget xorg-x11-server-Xvfb
# Arch:
sudo pacman -S wget xorg-server-xvfb

# 3. Follow the detailed setup steps below to:
#    - Copy scripts to /opt/lmstudio/
#    - Copy systemd files to /etc/systemd/system/
#    - Replace <YOUR_USERNAME> placeholders
#    - Download and extract LM Studio
```

---

## 🎯 The Goal: A Robust Headless Stack

We will create a multi-layered service that ensures:

1.  **Head
| **Fedora** | `sudo dnf install wget xorg-x11-server-Xvfb` |
| **Debian/Ubuntu** | `sudo apt install wget xvfb` |
| **Arch Linux** | `sudo pacman -S wget xorg-server-xvfb` |

---

## 🛠 Step 1: Initial Setup

We will use `/opt/lmstudio` as the **INSTALL_DIR** and replace `<YOUR_USERNAME>` with your actual Linux username throughout this guide.

### 1. Create the Directory and Set Permissions

**⚠️ IMPORTANT**: Replace `<YOUR_USERNAME>` with your actual Linux username in all commands and configuration files below.

```bash
# Create the main installation directory
sudo mkdir -p /opt/lmstudio

# Give your user ownership of the directory
sudo chown <YOUR_USERNAME>:<YOUR_USERNAME> /opt/lmstudio
```

### 2. Copy Scripts from Repository

If you cloned this repository, copy the scripts to the installation directory:

```bash
# From within the cloned repository directory
cp scripts/lmstudio-run.sh /opt/lmstudio/
cp scripts/update-lmstudio.sh /opt/lmstudio/

# Make them executable
chmod +x /opt/lmstudio/lmstudio-run.sh
chmod +x /opt/lmstudio/update-lmstudio.sh

# Edit the scripts to replace <YOUR_USERNAME> with your actual username
sed -i 's/<YOUR_USERNAME>/'"$USER"'/g' /opt/lmstudio/lmstudio-run.sh
sed -i 's/<YOUR_USERNAME>/'"$USER"'/g' /opt/lmstudio/update-lmstudio.sh
```

### 3. Download the AppImage Manually (Initial Run)

The service relies on the file being present and extracted. Download the latest version now:

```bash
cd /opt/lmstudio
wget -O LM-Studio-latest.AppImage https://lmstudio.ai/download/latest/linux/x64
chmod +x LM-Studio-latest.AppImage
```

### 4. Extract the AppImage

```bash
./LM-Studio-latest.AppImage --appimage-extract
```

This creates a `squashfs-root` directory with the actual application.

---

## ⚙ Step 2: The Run Script (Headless Engine)

This wrapper script launches the extracted AppImage binary using `xvfb-run`. This is what the Systemd service will execute.

If you copied the script from the repository in Step 1, it's already in place at `/opt/lmstudio/lmstudio-run.sh`. Otherwise, create it manually:

**Create:** `/opt/lmstudio/lmstudio-run.sh`

```bash
#!/bin/bash

# Set Home to the service user's home (essential for configs)
export HOME=/home/<YOUR_USERNAME>

# Navigate to the extracted folder
cd /opt/lmstudio/squashfs-root || exit 1

# Launch with xvfb-run to simulate a display, and use --headless for server mode
exec xvfb-run --auto-servernum --server-args='-screen 0 1024x768x24' \
    ./lm-studio --no-sandbox --headless
```

**Make it executable:**

```bash
chmod +x /opt/lmstudio/lmstudio-run.sh
```

---

## 🚀 Step 3: The Main Systemd Service

This is the core unit file that starts your server at boot.

If you cloned the repository, copy the systemd file and update the username:

```bash
# Copy from repository to system location
sudo cp systemd/lmstudio.service /etc/systemd/system/

# Edit to replace <YOUR_USERNAME> with your actual username
sudo sed -i 's/<YOUR_USERNAME>/'"$USER"'/g' /etc/systemd/system/lmstudio.service
```

Or create it manually:

**Create:** `/etc/systemd/system/lmstudio.service`

```ini
[Unit]
Description=LM Studio Headless Service
# Start only after network is ready
After=network-online.target
Wants=network-online.target

[Service]
# Run as your specific user, not root
User=<YOUR_USERNAME>
Group=<YOUR_USERNAME>

# The script that runs the application
ExecStart=/opt/lmstudio/lmstudio-run.sh

# Restart automatically if it crashes
Restart=always
RestartSec=10

# Set timeout for startup (models can take time to load)
TimeoutStartSec=300

[Install]
# CRUCIAL: Starts at boot before any user logs in
WantedBy=multi-user.target
```

---

## 🔄 Step 4: The Auto-Update System

Since the download URL is stable, we can create a Systemd Timer to handle periodic updates.

### 1. Create the Update Script

This script downloads the new file, performs the necessary **extraction** (which overwrites the `squashfs-root` folder), and fixes permissions.

If you copied from the repository in Step 1, the script is already at `/opt/lmstudio/update-lmstudio.sh`. Otherwise, create it manually:

**Create:** `/opt/lmstudio/update-lmstudio.sh`

```bash
#!/bin/bash

SERVICE_USER="<YOUR_USERNAME>"
INSTALL_DIR="/opt/lmstudio"
DOWNLOAD_URL="https://lmstudio.ai/download/latest/linux/x64"
NEW_FILE="LM-Studio-latest.AppImage"

echo "$(date): Starting Update..." | tee -a "$INSTALL_DIR/update.log"
cd "$INSTALL_DIR" || exit 1

# 1. Download latest
echo "Downloading latest version..."
wget -q --show-progress -O "$NEW_FILE.tmp" "$DOWNLOAD_URL"
if [ $? -ne 0 ]; then
    echo "$(date): Download failed." | tee -a "$INSTALL_DIR/update.log"
    rm -f "$NEW_FILE.tmp"
    exit 1
fi

# 2. Stop Service
echo "Stopping LM Studio service..."
systemctl stop lmstudio.service

# 3. Backup & Replace
echo "Creating backup and replacing AppImage..."
rm -rf squashfs-root.bak
mv squashfs-root squashfs-root.bak 2>/dev/null
mv "$NEW_FILE.tmp" "$NEW_FILE"
chmod +x "$NEW_FILE"

# 4. Extract (Crucial for headless execution)
echo "Extracting AppImage..."
./"$NEW_FILE" --appimage-extract > /dev/null

# 5. Fix Permissions
echo "Fixing permissions..."
chown -R $SERVICE_USER:$SERVICE_USER "$INSTALL_DIR"

# 6. Restart Service
echo "Restarting LM Studio service..."
systemctl start lmstudio.service

echo "$(date): Update Complete." | tee -a "$INSTALL_DIR/update.log"
```

**Make it executable:**

```bash
sudo chmod +x /opt/lmstudio/update-lmstudio.sh
```

### 2. Create the Update Service and Timer

If you cloned the repository, copy the systemd files:

```bash
# Copy update service and timer from repository
sudo cp systemd/lmstudio-update.service /etc/systemd/system/
sudo cp systemd/lmstudio-update.timer /etc/systemd/system/
```

Or create them manually:

**Update Service (`/etc/systemd/system/lmstudio-update.service`):**

```ini
[Unit]
Description=LM Studio Auto-Update Runner

[Service]
Type=oneshot
ExecStart=/opt/lmstudio/update-lmstudio.sh
User=root
StandardOutput=journal
StandardError=journal
```

**Update Timer (`/etc/systemd/system/lmstudio-update.timer` - runs weekly):**

```ini
[Unit]
Description=Weekly Timer for LM Studio Updates

[Timer]
# Runs every Monday at 4:00 AM
OnCalendar=Mon *-*-* 04:00:00
Persistent=true
Unit=lmstudio-update.service

[Install]
WantedBy=timers.target
```

---

## ✅ Step 5: Finalization and Firewall

### 1. Enable and Start Services

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable main service and start it immediately
sudo systemctl enable --now lmstudio.service

# Enable the weekly update timer
sudo systemctl enable --now lmstudio-update.timer
```

### 2. Verify Service Status

```bash
# Check service status
systemctl status lmstudio.service

# View recent logs
journalctl -u lmstudio.service -n 50 -f
```

Expected output should show `Active: active (running)`.

### 3. Open the Firewall Port

The LM Studio server runs on TCP port **1234** by default. You must open this port to access the API server from outside the host machine.

| Distribution | Command |
|:-------------|:--------|
| **Fedora** | `sudo firewall-cmd --add-port=1234/tcp --permanent`<br>`sudo firewall-cmd --reload` |
| **Debian/Ubuntu**| `sudo ufw allow 1234/tcp` |
| **Arch Linux (Using UFW)** | `sudo ufw allow 1234/tcp` |

**For production use**, consider restricting to specific IP addresses:

```bash
# UFW example - allow only from specific subnet
sudo ufw allow from 192.168.1.0/24 to any port 1234
```

---

## 🔍 Troubleshooting

### View Service Logs

```bash
# Live log tail
journalctl -u lmstudio.service -f

# Last 100 lines
journalctl -u lmstudio.service -n 100

# Logs since last boot
journalctl -u lmstudio.service -b
```

### Check Update Timer Status

```bash
# View timer status
systemctl status lmstudio-update.timer

# List next scheduled run
systemctl list-timers lmstudio-update.timer
```

### Manual Update Trigger

```bash
# Run update manually
sudo /opt/lmstudio/update-lmstudio.sh

# Or trigger via systemd
sudo systemctl start lmstudio-update.service
```

### Service Won't Start

1. **Check permissions**:
   ```bash
   ls -la /opt/lmstudio/
   # Ensure <YOUR_USERNAME> owns all files
   ```

2. **Verify Xvfb is running**:
   ```bash
   ps aux | grep Xvfb
   ```

3. **Check for port conflicts**:
   ```bash
   sudo netstat -tlnp | grep 1234
   # Or
   sudo ss -tlnp | grep 1234
   ```

4. **Increase timeout** if models are large:
   Edit `/etc/systemd/system/lmstudio.service` and increase `TimeoutStartSec=600`

### Model Not Loading

Configure models via the LM Studio CLI before enabling headless mode:

```bash
# List available models
~/.cache/lm-studio/bin/lms ls

# Load a specific model
~/.cache/lm-studio/bin/lms load <model-identifier>

### Desktop Integration (Hybrid Mode)
If you use the desktop GUI frequently, you can install a "Hybrid" launcher that automatically stops the headless service when you open the GUI and restarts it when you close it.

1.  **Copy the launcher script**:
    ```bash
    sudo cp scripts/launch-gui.sh /opt/lmstudio/
    sudo chmod +x /opt/lmstudio/launch-gui.sh
    ```

2.  **Install the Desktop Shortcut**:
    ```bash
    # Copy the .desktop file to your applications folder
    sudo cp systemd/lm-studio-gui.desktop /usr/share/applications/
    ```

3.  **Use it**:
    Search for "LM Studio (Hybrid)" in your application menu. When you click it:
    - It will ask for your password (to stop the service).
    - It will open LM Studio.
    - When you close LM Studio, it will automatically restart the background service.

### Conflict with Desktop GUI
If you are running this on a desktop Linux environment, you cannot run the LM Studio GUI and this headless service simultaneously.
- **Symptom**: The GUI won't open, or the window keeps popping to the foreground.
- **Solution**: Stop the service before opening the GUI: `sudo systemctl stop lmstudio.service`.
- **Note**: The service is configured with `Restart=on-failure` to prevent restart loops if the GUI is already running.
```

---

## 🧪 Testing Your Installation

### 1. Check API Endpoint

```bash
curl http://localhost:1234/v1/models
```

### 2. Test Chat Completion

```bash
curl http://localhost:1234/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "your-model-name",
    "messages": [{"role": "user", "content": "Hello!"}],
    "temperature": 0.7
  }'
```

### 3. Remote Access Test

From another machine on your network:

```bash
curl http://<server-ip>:1234/v1/models
```

---

## 📊 Where Files Are Stored

- **Application**: `/opt/lmstudio/squashfs-root/`
- **Models**: `~/.cache/lm-studio/models/`
- **Configuration**: `~/.config/LM-Studio/`
- **Update logs**: `/opt/lmstudio/update.log`
- **Service logs**: `journalctl -u lmstudio.service`

---

## 🔒 Security Recommendations

1. **Use a reverse proxy** (nginx/Caddy) with authentication:
   ```nginx
   location /api {
       auth_basic "LM Studio API";
       auth_basic_user_file /etc/nginx/.htpasswd;
       proxy_pass http://localhost:1234;
   }
   ```

2. **Restrict firewall** to known IPs only

3. **Enable HTTPS** using Let's Encrypt with your reverse proxy

4. **Monitor resource usage**:
   ```bash
   # Add to crontab for alerts
   watch -n 60 'free -h && nvidia-smi'
   ```

5. **Regular backups** of your model configurations

---

## 🎛️ Advanced Configuration

### Custom Port

Edit `/opt/lmstudio/lmstudio-run.sh` and add:

```bash
export LMS_SERVER_PORT=8080
```

### GPU Selection

For multi-GPU systems, specify which GPU to use:

```bash
export CUDA_VISIBLE_DEVICES=0  # Use first GPU only
```

### Resource Limits

Add to `/etc/systemd/system/lmstudio.service` under `[Service]`:

```ini
MemoryMax=24G
CPUQuota=400%  # Use 4 CPU cores max
```

---

## 📝 License

This guide is released under the MIT License. Feel free to modify and distribute.

```
MIT License

Copyright (c) 2025 Sterlen Johnson

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## 🤝 Contributing

Found an issue or have an improvement? Please open an issue or pull request on GitHub.

### How to Contribute

1. **Report Issues**: Found a bug or compatibility issue? [Open an issue](../../issues/new)
2. **Submit Improvements**: Have a better approach? Submit a pull request
3. **Share Your Setup**: Tested on a different distribution? Let us know!
4. **Improve Documentation**: Found something unclear? Help make it better

### Contribution Guidelines

- Test your changes on at least one Linux distribution
- Update the "Testing Status" section if you verify compatibility
- Follow the existing markdown formatting style
- Add troubleshooting entries for any issues you solve

### Recognition

Contributors will be acknowledged in the README. Thank you for helping improve this guide!

## 📚 Additional Resources

- [LM Studio Official Documentation](https://lmstudio.ai/docs)
- [LM Studio Discord Community](https://discord.gg/lmstudio)
- [Systemd Documentation](https://www.freedesktop.org/software/systemd/man/)
- [LM Studio Terms of Service](https://lmstudio.ai/app-terms)

---

## ✅ Final Verification

After completing all steps:

1. ✅ Service starts automatically on boot
2. ✅ Service recovers from crashes
3. ✅ Updates run weekly without intervention
4. ✅ API accessible from network (if firewall configured)
5. ✅ Logs are being captured by systemd

You now have a production-ready, 24/7 LLM server! 🎉
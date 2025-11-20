🤖 Running LM Studio Headless: A Systemd Guide for 24/7 LLM Service

Want to host your favorite Large Language Models (LLMs) from LM Studio 24/7 on a Linux server without a graphical interface? Setting up a truly headless, auto-updating, and auto-restarting service requires leveraging Linux's built-in service manager: Systemd.

This guide provides a robust, generalized configuration for Debian, Fedora, and Arch-based systems.

⚠️ Important Disclaimers

Terms of Service: LM Studio is free for both personal and work use. This guide involves automated downloads of LM Studio, which is permitted under their terms. Review LM Studio's Terms of Service if you have specific compliance concerns.

Security Notice: This setup exposes LM Studio's API server on your network. Ensure you:

Run this on a trusted/protected network

Consider implementing authentication via a reverse proxy (nginx/traefik)

Use a firewall to restrict access to authorized IP addresses only

Avoid exposing port 1234 directly to the internet without proper security measures

Acknowledgments: This guide was inspired by community efforts, including work by Angelo Artuso and the run.tournament.org.il project, but provides a more comprehensive and automated solution for true headless deployments.

Testing Status: This guide has been tested on Ubuntu 24.04, Fedora 40, and Arch Linux. Report issues via GitHub issues.

Resource Requirements:

Minimum 16GB RAM (32GB+ recommended for larger models)

GPU with adequate VRAM for your target models (8GB+ recommended)

At least 50GB free storage for models and updates

x86_64 processor with AVX2 support

🎯 The Goal: A Robust Headless Stack

We will create a multi-layered service that ensures:

Headless Execution: Runs without a graphical desktop using a virtual display.

Autostart: Starts automatically at boot, before any user login.

Auto-Restart: Automatically recovers if the service crashes.

Auto-Update: Periodically checks, downloads, and extracts the latest LM Studio AppImage.

📦 Prerequisites: Install Dependencies

Before configuring Systemd, you need wget (for downloads) and Xvfb (Virtual Frame Buffer) to simulate a display, which is required by the Electron backend.

Execute the command corresponding to your distribution:

Distribution

Command

Fedora

sudo dnf install wget xorg-x11-server-Xvfb

Debian/Ubuntu

sudo apt install wget xvfb

Arch Linux

sudo pacman -S wget xorg-server-xvfb

🛠 Step 1: Initial Setup

We will use /opt/lmstudio as the INSTALL_DIR and replace <YOUR_USERNAME> with your actual Linux username throughout this guide.

1. Create the Directory and Set Permissions

⚠️ IMPORTANT: You must replace all instances of <YOUR_USERNAME> with your actual Linux username in the configuration files (lmstudio-run.sh, lmstudio.service, etc.) before deployment.

# Create the main installation directory
sudo mkdir -p /opt/lmstudio

# Give your user ownership of the directory
sudo chown <YOUR_USERNAME>:<YOUR_USERNAME> /opt/lmstudio


2. Download and Extract the AppImage Manually (Initial Run)

The service relies on the file being present and extracted. Download and extract the latest version now:

cd /opt/lmstudio
wget -O LM-Studio-latest.AppImage [https://lmstudio.ai/download/latest/linux/x64](https://lmstudio.ai/download/latest/linux/x64)
chmod +x LM-Studio-latest.AppImage

# This creates a 'squashfs-root' directory with the actual application binary.
./LM-Studio-latest.AppImage --appimage-extract


⚙ Step 2: Deployment and Final Configuration

These files must be moved from the GitHub repository structure (scripts/, systemd/) to the Linux server's appropriate directories.

1. Copy Configuration Files

Assuming you have cloned this repository, copy the files to their final destinations on your server:

# Copy executable scripts to the installation directory
sudo cp scripts/lmstudio-run.sh /opt/lmstudio/
sudo cp scripts/update-lmstudio.sh /opt/lmstudio/

# Copy Systemd units to the system directory
sudo cp systemd/lmstudio.service /etc/systemd/system/
sudo cp systemd/lmstudio-update.service /etc/systemd/system/
sudo cp systemd/lmstudio-update.timer /etc/systemd/system/

# Ensure scripts are executable
sudo chmod +x /opt/lmstudio/lmstudio-run.sh
sudo chmod +x /opt/lmstudio/update-lmstudio.sh


2. The LM Studio Run Script (Headless Engine)

This wrapper script launches the extracted AppImage binary using xvfb-run. This is what the Systemd service will execute.

File: scripts/lmstudio-run.sh

3. The Main Systemd Service

This is the core unit file that starts your server at boot.

File: systemd/lmstudio.service

4. The Auto-Update System Components

These files configure the weekly update check.

Update Service (File: systemd/lmstudio-update.service):
Update Script (File: scripts/update-lmstudio.sh):
Update Timer (File: systemd/lmstudio-update.timer):

✅ Step 3: Finalization and Firewall

1. Enable and Start Services

# Reload systemd
sudo systemctl daemon-reload

# Enable main service and start it immediately
sudo systemctl enable --now lmstudio.service

# Enable the weekly update timer
sudo systemctl enable --now lmstudio-update.timer


2. Verify Service Status

# Check service status
systemctl status lmstudio.service

# View recent logs
journalctl -u lmstudio.service -n 50 -f


Expected output should show Active: active (running).

3. Open the Firewall Port

The LM Studio server runs on TCP port 1234 by default. You must open this port to access the API server from outside the host machine.

Distribution

Command

Fedora

```bash

sudo firewall-cmd --add-port=1234/tcp --permanent



sudo firewall-cmd --reload



| **Debian/Ubuntu** | `sudo ufw allow 1234/tcp` |
| **Arch Linux (Using UFW)** | `sudo ufw allow 1234/tcp` |

**For production use, consider restricting to specific IP addresses:**

```bash
# UFW example - allow only from specific subnet
sudo ufw allow from 192.168.1.0/24 to any port 1234


🔍 Troubleshooting

View Service Logs

# Live log tail
journalctl -u lmstudio.service -f

# Last 100 lines
journalctl -u lmstudio.service -n 100

# Logs since last boot
journalctl -u lmstudio.service -b


Check Update Timer Status

# View timer status
systemctl status lmstudio-update.timer

# List next scheduled run
systemctl list-timers lmstudio-update.timer


Manual Update Trigger

# Run update manually
sudo /opt/lmstudio/update-lmstudio.sh

# Or trigger via systemd
sudo systemctl start lmstudio-update.service


Service Won't Start

Check permissions:

ls -la /opt/lmstudio/
# Ensure <YOUR_USERNAME> owns all files


Verify Xvfb is running: ps aux | grep Xvfb

Check for port conflicts: sudo ss -tlnp | grep 1234

Increase timeout if models are large: Edit /etc/systemd/system/lmstudio.service and increase TimeoutStartSec=600

Model Not Loading

You must configure models via the LM Studio CLI before enabling headless mode. This usually happens in the user's $HOME directory (/home/<YOUR_USERNAME>).

# List available models
~/.cache/lm-studio/bin/lms ls

# Load a specific model
~/.cache/lm-studio/bin/lms load <model-identifier>


🧪 Testing Your Installation

Check API Endpoint:

curl http://localhost:1234/v1/models


Test Chat Completion:

curl http://localhost:1234/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "your-model-name",
    "messages": [{"role": "user", "content": "Hello!"}],
    "temperature": 0.7
  }'


Remote Access Test:
From another machine on your network:

curl http://<server-ip>:1234/v1/models


📊 Where Files Are Stored

Type of File

Location

Application

/opt/lmstudio/squashfs-root/

Models

~/.cache/lm-studio/models/

Configuration

~/.config/LM-Studio/

Update logs

/opt/lmstudio/update.log

Service logs

journalctl -u lmstudio.service

🔒 Security Recommendations

Use a reverse proxy (nginx/Caddy) with authentication:

location /api {
    auth_basic "LM Studio API";
    auth_basic_user_file /etc/nginx/.htpasswd;
    proxy_pass http://localhost:1234;
}


Restrict firewall to known IPs only.

Enable HTTPS using Let's Encrypt with your reverse proxy.

Monitor resource usage: watch -n 60 'free -h && nvidia-smi'

Regular backups of your model configurations.

🎛️ Advanced Configuration

Custom Port

Edit scripts/lmstudio-run.sh and add:

export LMS_SERVER_PORT=8080


GPU Selection

For multi-GPU systems, specify which GPU to use by editing scripts/lmstudio-run.sh:

export CUDA_VISIBLE_DEVICES=0  # Use first GPU only


Resource Limits

Add to systemd/lmstudio.service under [Service]:

MemoryMax=24G
CPUQuota=400%  # Use 4 CPU cores max


📝 License

This guide is released under the MIT License. Feel free to modify and distribute.

�� Contributing

Found an issue or have an improvement? Please open an issue or pull request on GitHub.

📚 Additional Resources

LM Studio Official Documentation

Systemd Documentation

LM Studio Terms of Service

✅ Final Verification
After completing all steps:

✅ Service starts automatically on boot

✅ Service recovers from crashes

✅ Updates run weekly without intervention

✅ API accessible from network (if firewall configured)

✅ Logs are being captured by systemd

You now have a production-ready, 24/7 LLM server! 🎉

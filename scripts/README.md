# Scripts

Utility scripts for Jenkins deployment and management.

## Overview

| Script | Purpose | Usage |
|--------|---------|-------|
| `deploy.sh` | Manual app deployment | `./deploy.sh <host> [user] [path]` |
| `setup-deploy-target.sh` | Prepare deployment server | `sudo ./setup-deploy-target.sh` |
| `setup-nginx-reverseproxy.sh` | Configure Nginx reverse proxy | `sudo ./setup-nginx-reverseproxy.sh` |
| `python-app.service` | Systemd service template | Copy to `/etc/systemd/system/` |

## deploy.sh

Deploy the Python application manually (without Jenkins).

**Usage:**
```bash
./deploy.sh <host> [user] [path]
```

**Examples:**
```bash
# Deploy to production server
./deploy.sh prod.example.com jenkins /opt/python-app

# Deploy to localhost
./deploy.sh localhost

# Deploy with custom user
./deploy.sh 192.168.1.100 appuser
```

**Requirements:**
- SSH access to target host
- Python 3.11+ on target host
- Target host configured with `setup-deploy-target.sh`

## setup-deploy-target.sh

Prepare a server to receive application deployments.

**Usage:**
```bash
sudo ./setup-deploy-target.sh
```

**What it does:**
1. Creates `jenkins` user for deployments
2. Sets up `/opt/python-app` directory
3. Installs Python and dependencies
4. Configures systemd service
5. Opens firewall port 5000
6. Sets up SSH directory

**Post-setup:**
```bash
# Add Jenkins controller's SSH public key
sudo -u jenkins sh -c 'echo "ssh-rsa AAAA..." >> /home/jenkins/.ssh/authorized_keys'

# Test SSH access
ssh jenkins@<target-host>
```

## setup-nginx-reverseproxy.sh

Install and configure Nginx as a reverse proxy for Jenkins.

**Usage:**
```bash
sudo ./setup-nginx-reverseproxy.sh
```

**What it does:**
1. Installs Nginx
2. Creates reverse proxy configuration
3. Configures SELinux permissions
4. Opens HTTP/HTTPS firewall ports
5. Starts Nginx service

**Post-setup for HTTPS:**
```bash
# Install certbot
sudo dnf install certbot python3-certbot-nginx

# Obtain certificate
sudo certbot --nginx -d jenkins.example.com

# Or manually edit /etc/nginx/conf.d/jenkins.conf
# Uncomment HTTPS server block and update paths
```

## python-app.service

Systemd unit file for the Python application.

**Configuration:**
```ini
[Unit]
Description=Python Flask Application
After=network.target

[Service]
Type=simple
User=jenkins
Group=jenkins
WorkingDirectory=/opt/python-app
Environment="PATH=/opt/python-app/venv/bin"
ExecStart=/opt/python-app/venv/bin/gunicorn \
    --workers 4 \
    --bind 0.0.0.0:5000 \
    app:app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

**Usage:**
```bash
# Enable service
sudo systemctl enable python-app

# Start service
sudo systemctl start python-app

# Check status
sudo systemctl status python-app

# View logs
sudo journalctl -u python-app -f

# Restart service
sudo systemctl restart python-app
```

## Common Workflows

### Initial Setup

```bash
# 1. On deployment target
sudo ./setup-deploy-target.sh

# 2. On Jenkins controller, copy SSH key to target
ssh-copy-id jenkins@<target-host>

# 3. Test deployment
./deploy.sh <target-host>

# 4. Verify
curl http://<target-host>:5000/health
```

### Update Application

```bash
# Manual deployment
./deploy.sh <target-host>

# Or via Jenkins pipeline
# Push code to Git → Jenkins auto-deploys
```

### Troubleshooting

**Check deployment logs:**
```bash
ssh jenkins@<target-host>
sudo journalctl -u python-app -n 50
```

**Test connectivity:**
```bash
# SSH
ssh jenkins@<target-host> echo "Connected"

# HTTP
curl http://<target-host>:5000/health
```

**Restart services:**
```bash
# Application
ssh jenkins@<target-host> sudo systemctl restart python-app

# Nginx (if using reverse proxy)
ssh jenkins@<target-host> sudo systemctl restart nginx
```

## Security Considerations

- Scripts use `set -euo pipefail` for safety
- SSH key-based authentication required
- Firewall rules limit access to necessary ports
- Services run as non-root `jenkins` user
- SELinux configured for Nginx proxy

## Customization

All scripts support environment variable overrides:

```bash
# Custom deployment path
DEPLOY_PATH=/var/www/myapp ./deploy.sh host

# Custom service user
SERVICE_USER=www-data ./setup-deploy-target.sh
```

Edit scripts directly for permanent changes.

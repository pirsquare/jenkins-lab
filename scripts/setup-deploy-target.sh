#!/bin/bash
set -euo pipefail

# Setup Python app deployment target
# Run this script on the server where the app will be deployed

echo "Setting up Python app deployment environment..."
echo "---"

# Check if running as root or with sudo access
if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
    echo "Error: This script requires sudo privileges"
    exit 1
fi

# Create deployment user if doesn't exist
echo "[1/5] Checking deployment user..."
if ! id jenkins &>/dev/null; then
    sudo useradd -m -s /bin/bash jenkins
    echo "  ✓ Created user 'jenkins'"
else
    echo "  ✓ User 'jenkins' already exists"
fi

# Create deployment directory
echo "[2/5] Setting up deployment directory..."
sudo mkdir -p /opt/python-app
sudo chown jenkins:jenkins /opt/python-app
echo "  ✓ Directory created: /opt/python-app"

# Install Python and dependencies
echo "[3/5] Installing Python and dependencies..."
sudo dnf -y install python3 python3-pip python3-devel >/dev/null 2>&1 || {
    echo "  ✗ Failed to install Python"
    exit 1
}
echo "  ✓ Python installed: $(python3 --version)"

# Copy systemd service file
echo "[4/5] Installing systemd service..."
if [[ -f "python-app.service" ]]; then
    sudo cp python-app.service /etc/systemd/system/
    sudo systemctl daemon-reload
    echo "  ✓ Service file installed"
else
    echo "  ! Warning: python-app.service not found in current directory"
    echo "    Copy it manually later to /etc/systemd/system/"
fi

# Configure firewall for app port
echo "[5/5] Configuring firewall..."
if command -v firewall-cmd >/dev/null 2>&1; then
    sudo firewall-cmd --permanent --add-port=5000/tcp >/dev/null 2>&1 || true
    sudo firewall-cmd --reload >/dev/null 2>&1 || true
    echo "  ✓ Firewall configured (port 5000/tcp)"
else
    echo "  ! Warning: firewalld not found, configure firewall manually"
fi

# Setup SSH directory
sudo mkdir -p /home/jenkins/.ssh
sudo chmod 700 /home/jenkins/.ssh
sudo touch /home/jenkins/.ssh/authorized_keys
sudo chmod 600 /home/jenkins/.ssh/authorized_keys
sudo chown -R jenkins:jenkins /home/jenkins/.ssh

echo "---"
echo "Deployment target setup complete!"
echo ""
echo "Next steps:"
echo "1. Add Jenkins controller's SSH public key:"
echo "   sudo -u jenkins sh -c 'echo \"<public-key>\" >> /home/jenkins/.ssh/authorized_keys'"
echo ""
echo "2. Test SSH access from Jenkins controller:"
echo "   ssh jenkins@$(hostname -I | awk '{print $1}')"
echo ""
echo "3. Configure Jenkins:"
echo "   - Add SSH credentials for user 'jenkins'"
echo "   - Create pipeline job using Jenkinsfile"
echo "   - Set DEPLOY_HOST to $(hostname -I | awk '{print $1}')"

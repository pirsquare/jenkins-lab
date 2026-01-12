#!/bin/bash
set -euo pipefail

# Manual deployment script for Python app
# Usage: ./deploy.sh <host> [user] [path]

DEPLOY_HOST="${1:-}"
DEPLOY_USER="${2:-jenkins}"
DEPLOY_PATH="${3:-/opt/python-app}"

# Validation
if [[ -z "${DEPLOY_HOST}" ]]; then
    echo "Error: Deployment host is required"
    echo "Usage: $0 <host> [user] [path]"
    echo "Example: $0 192.168.1.100 jenkins /opt/python-app"
    exit 1
fi

if [[ ! -d "sample-app" ]]; then
    echo "Error: sample-app directory not found. Run from project root."
    exit 1
fi

echo "Deploying Python app to ${DEPLOY_USER}@${DEPLOY_HOST}:${DEPLOY_PATH}"
echo "---"

# Package the app
echo "[1/4] Packaging application..."
cd sample-app
tar czf ../python-app.tar.gz \
    --exclude=venv \
    --exclude=__pycache__ \
    --exclude='*.pyc' \
    --exclude=.pytest_cache \
    .
cd ..
echo "  ✓ Package created: python-app.tar.gz"

# Deploy
echo "[2/4] Copying to remote host..."
scp -q python-app.tar.gz "${DEPLOY_USER}@${DEPLOY_HOST}:/tmp/" || {
    echo "  ✗ Failed to copy to remote host"
    rm -f python-app.tar.gz
    exit 1
}
echo "  ✓ Files copied"

echo "[3/4] Installing on remote host..."
ssh "${DEPLOY_USER}@${DEPLOY_HOST}" bash <<EOF
set -euo pipefail
sudo mkdir -p ${DEPLOY_PATH}
sudo tar xzf /tmp/python-app.tar.gz -C ${DEPLOY_PATH}
cd ${DEPLOY_PATH}
python3 -m venv venv
. venv/bin/activate
pip install -q --upgrade pip
pip install -q -r requirements.txt
rm -f /tmp/python-app.tar.gz
EOF
echo "  ✓ Application installed"

echo "[4/4] Starting service..."
ssh "${DEPLOY_USER}@${DEPLOY_HOST}" \
    'sudo systemctl enable python-app && sudo systemctl restart python-app' || {
    echo "  ✗ Failed to start service"
    rm -f python-app.tar.gz
    exit 1
}
echo "  ✓ Service started"

# Cleanup
rm -f python-app.tar.gz

echo "---"
echo "Deployment complete!"
echo "Application URL: http://${DEPLOY_HOST}:5000"
echo ""
echo "Verify deployment:"
echo "  curl http://${DEPLOY_HOST}:5000/health"

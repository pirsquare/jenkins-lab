#!/bin/bash
set -euo pipefail

# Basic deps
sudo dnf -y update
sudo dnf -y install java-17-openjdk wget curl ca-certificates gnupg2

# Jenkins repo and key
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
sudo tee /etc/yum.repos.d/jenkins.repo >/dev/null <<'EOF'
[jenkins]
name=Jenkins-stable
baseurl=https://pkg.jenkins.io/redhat-stable
gpgcheck=1
gpgkey=https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
enabled=1
EOF

sudo dnf -y install jenkins
sudo systemctl enable --now jenkins

# Firewall rules if firewalld is present
if command -v firewall-cmd >/dev/null 2>&1; then
  sudo firewall-cmd --permanent --add-service=ssh || true
  sudo firewall-cmd --permanent --add-port=8080/tcp || true
  sudo firewall-cmd --reload || true
fi

# Optional: seed JCasC location (uncomment if mounting /var/lib/jenkins/casc)
# sudo mkdir -p /var/lib/jenkins/casc
# sudo chown -R jenkins:jenkins /var/lib/jenkins/casc
# echo "CASC_JENKINS_CONFIG=/var/lib/jenkins/casc/jenkins.yaml" | sudo tee -a /etc/sysconfig/jenkins
# sudo systemctl restart jenkins

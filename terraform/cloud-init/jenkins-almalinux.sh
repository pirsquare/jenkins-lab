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

# Install and configure Nginx as reverse proxy
sudo dnf -y install nginx

sudo tee /etc/nginx/conf.d/jenkins.conf >/dev/null <<'NGINXEOF'
upstream jenkins {
  keepalive 32;
  server 127.0.0.1:8080;
}

map $http_upgrade $connection_upgrade {
  default upgrade;
  '' close;
}

server {
  listen 80;
  server_name _;

  access_log /var/log/nginx/jenkins.access.log;
  error_log /var/log/nginx/jenkins.error.log;

  ignore_invalid_headers off;

  location / {
    proxy_pass http://jenkins;
    proxy_redirect default;
    proxy_http_version 1.1;

    proxy_set_header Connection $connection_upgrade;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Port $server_port;

    proxy_connect_timeout 150;
    proxy_send_timeout 100;
    proxy_read_timeout 100;
    proxy_request_buffering off;
    proxy_buffering off;
  }
}
NGINXEOF

# SELinux configuration for Nginx proxy
sudo setsebool -P httpd_can_network_connect 1

# Firewall rules if firewalld is present
if command -v firewall-cmd >/dev/null 2>&1; then
  sudo firewall-cmd --permanent --add-service=ssh || true
  sudo firewall-cmd --permanent --add-service=http || true
  sudo firewall-cmd --permanent --add-service=https || true
  sudo firewall-cmd --permanent --add-port=8080/tcp || true
  sudo firewall-cmd --reload || true
fi

# Start Nginx
sudo systemctl enable nginx
sudo systemctl restart nginx

# Optional: seed JCasC location (uncomment if mounting /var/lib/jenkins/casc)
# sudo mkdir -p /var/lib/jenkins/casc
# sudo chown -R jenkins:jenkins /var/lib/jenkins/casc
# echo "CASC_JENKINS_CONFIG=/var/lib/jenkins/casc/jenkins.yaml" | sudo tee -a /etc/sysconfig/jenkins
# sudo systemctl restart jenkins

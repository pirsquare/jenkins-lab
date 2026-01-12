#!/bin/bash
set -euo pipefail

# Setup Nginx as reverse proxy for Jenkins on AlmaLinux
# This script installs Nginx and configures it to proxy Jenkins on port 8080

echo "Installing Nginx..."
sudo dnf -y install nginx

echo "Creating Nginx configuration for Jenkins..."
sudo tee /etc/nginx/conf.d/jenkins.conf >/dev/null <<'EOF'
upstream jenkins {
  keepalive 32; # keepalive connections
  server 127.0.0.1:8080; # Jenkins is running on port 8080
}

# HTTP server - can be upgraded to HTTPS
server {
  listen 80;
  server_name _; # Replace with your domain, e.g., jenkins.example.com

  # Uncomment below to redirect HTTP to HTTPS
  # return 301 https://$host$request_uri;

  # Logging
  access_log /var/log/nginx/jenkins.access.log;
  error_log /var/log/nginx/jenkins.error.log;

  # Pass through headers from Jenkins
  ignore_invalid_headers off;

  location / {
    proxy_pass http://jenkins;
    proxy_redirect default;
    proxy_http_version 1.1;

    # Required for Jenkins WebSocket agents
    proxy_set_header Connection $connection_upgrade;
    proxy_set_header Upgrade $http_upgrade;

    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Port $server_port;

    # Increase timeouts for long-running builds
    proxy_connect_timeout 150;
    proxy_send_timeout 100;
    proxy_read_timeout 100;

    # Required for new HTTP-based CLI
    proxy_request_buffering off;
    proxy_buffering off;
  }
}

# HTTPS server (uncomment and configure after obtaining TLS certificate)
# server {
#   listen 443 ssl http2;
#   server_name jenkins.example.com; # Replace with your domain
#
#   # TLS certificate paths - use Let's Encrypt or other CA
#   ssl_certificate /etc/letsencrypt/live/jenkins.example.com/fullchain.pem;
#   ssl_certificate_key /etc/letsencrypt/live/jenkins.example.com/privkey.pem;
#
#   # Modern TLS configuration
#   ssl_protocols TLSv1.2 TLSv1.3;
#   ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
#   ssl_prefer_server_ciphers off;
#   ssl_session_cache shared:SSL:10m;
#   ssl_session_timeout 10m;
#
#   # HSTS (optional)
#   add_header Strict-Transport-Security "max-age=63072000" always;
#
#   # Logging
#   access_log /var/log/nginx/jenkins-ssl.access.log;
#   error_log /var/log/nginx/jenkins-ssl.error.log;
#
#   ignore_invalid_headers off;
#
#   location / {
#     proxy_pass http://jenkins;
#     proxy_redirect default;
#     proxy_http_version 1.1;
#
#     proxy_set_header Connection $connection_upgrade;
#     proxy_set_header Upgrade $http_upgrade;
#     proxy_set_header Host $host;
#     proxy_set_header X-Real-IP $remote_addr;
#     proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
#     proxy_set_header X-Forwarded-Proto $scheme;
#     proxy_set_header X-Forwarded-Port $server_port;
#
#     proxy_connect_timeout 150;
#     proxy_send_timeout 100;
#     proxy_read_timeout 100;
#     proxy_request_buffering off;
#     proxy_buffering off;
#   }
# }

# WebSocket upgrade support
map $http_upgrade $connection_upgrade {
  default upgrade;
  '' close;
}
EOF

echo "Configuring SELinux to allow Nginx to connect to Jenkins..."
# Allow Nginx to make network connections (required for reverse proxy)
sudo setsebool -P httpd_can_network_connect 1

echo "Configuring firewall..."
if command -v firewall-cmd >/dev/null 2>&1; then
  sudo firewall-cmd --permanent --add-service=http || true
  sudo firewall-cmd --permanent --add-service=https || true
  sudo firewall-cmd --reload || true
fi

echo "Starting and enabling Nginx..."
sudo systemctl enable nginx
sudo systemctl restart nginx

echo "Nginx reverse proxy setup complete!"
echo "Access Jenkins at: http://$(hostname -I | awk '{print $1}')"
echo ""
echo "To enable HTTPS:"
echo "1. Obtain TLS certificate (e.g., certbot for Let's Encrypt)"
echo "2. Edit /etc/nginx/conf.d/jenkins.conf and uncomment HTTPS server block"
echo "3. Update certificate paths and server_name"
echo "4. Run: sudo systemctl reload nginx"

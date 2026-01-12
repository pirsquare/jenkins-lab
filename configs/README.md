# Nginx Configuration Files

Pre-configured Nginx reverse proxy configurations for Jenkins.

## Files

- **nginx-http.conf** - HTTP-only configuration (port 80)
- **nginx-https.conf** - HTTPS with TLS termination (ports 80 → 443)

## Usage

### HTTP Only

```bash
sudo cp nginx-http.conf /etc/nginx/conf.d/jenkins.conf
sudo nginx -t
sudo systemctl reload nginx
```

### HTTPS with Let's Encrypt

```bash
# Install certbot
sudo dnf install -y certbot python3-certbot-nginx

# Obtain certificate
sudo certbot --nginx -d jenkins.example.com

# Or manually configure
sudo cp nginx-https.conf /etc/nginx/conf.d/jenkins.conf
# Edit the file and replace jenkins.example.com with your domain
sudo nginx -t
sudo systemctl reload nginx
```

## Customization

### Change Domain

Replace `jenkins.example.com` with your actual domain in the configuration files.

### Adjust Timeouts

Modify these values for long-running builds:
```nginx
proxy_connect_timeout 150;
proxy_send_timeout 100;
proxy_read_timeout 100;
```

### IP Whitelisting

Add IP restrictions:
```nginx
location / {
  allow 10.0.0.0/8;
  allow 192.168.1.0/24;
  deny all;
  
  proxy_pass http://jenkins;
  # ... rest of config
}
```

## Features

Both configurations include:
- WebSocket support for live console logs
- Proper header forwarding
- Connection keepalive
- Request buffering disabled (required for Jenkins CLI)
- Extended timeouts for long builds

## Troubleshooting

**Test configuration:**
```bash
sudo nginx -t
```

**Reload after changes:**
```bash
sudo systemctl reload nginx
```

**View logs:**
```bash
sudo tail -f /var/log/nginx/jenkins.access.log
sudo tail -f /var/log/nginx/jenkins.error.log
```

**Check SELinux (AlmaLinux/RHEL):**
```bash
sudo setsebool -P httpd_can_network_connect 1
```

# Jenkins Setup and Configuration Guide

Detailed instructions for configuring and using Jenkins for CI/CD.

## Table of Contents
- [Installation](#installation)
- [Configuration as Code (JCasC)](#configuration-as-code-jcasc)
- [Python App CI/CD Pipeline](#python-app-cicd-pipeline)
- [Reverse Proxy & TLS](#reverse-proxy--tls)
- [Backups and Restore](#backups-and-restore)

## Installation

### Docker (Quickest)
```sh
docker pull jenkins/jenkins:lts
docker run -d \
  --name jenkins \
  -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  jenkins/jenkins:lts
```
View admin password: `docker exec -it jenkins cat /var/jenkins_home/secrets/initialAdminPassword`

### AlmaLinux VM
```sh
sudo dnf -y update
sudo dnf -y install java-17-openjdk wget curl ca-certificates
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
```
- Admin password: `sudo cat /var/lib/jenkins/secrets/initialAdminPassword`
- Default port 8080; if firewalld is enabled: `sudo firewall-cmd --permanent --add-port=8080/tcp && sudo firewall-cmd --reload`

### Kubernetes (Helm)
```sh
helm repo add jenkins https://charts.jenkins.io
helm repo update
helm install jenkins jenkins/jenkins \
  --namespace jenkins --create-namespace \
  --set controller.serviceType=LoadBalancer
```
- Get admin password: `kubectl exec -n jenkins -it deploy/jenkins -- cat /var/jenkins_home/secrets/initialAdminPassword`
- For ingress: set `controller.ingress.enabled=true` and provide host/path annotations.

### Post-Install Steps
1. Navigate to `http://<jenkins-host>:8080`
2. Enter the initial admin password
3. Install recommended plugins
4. Create admin user account
5. Configure Jenkins URL in System Configuration

## Configuration as Code (JCasC)

JCasC allows you to define Jenkins configuration in YAML for reproducible setups.

### Using the Provided Configuration

See `casc/jenkins.yaml` for a starter configuration that:
- Sets system message
- Limits controller executors to 0 (encourage use of agents)
- Creates local admin user
- Seeds an example folder

### Docker with JCasC
```sh
docker run -d -p 8080:8080 \
  -v $PWD/casc:/var/jenkins_home/casc \
  -e CASC_JENKINS_CONFIG=/var/jenkins_home/casc/jenkins.yaml \
  jenkins/jenkins:lts-jdk17
```

### VM with JCasC
```sh
sudo mkdir -p /var/lib/jenkins/casc
sudo cp casc/jenkins.yaml /var/lib/jenkins/casc/
sudo chown -R jenkins:jenkins /var/lib/jenkins/casc
echo "CASC_JENKINS_CONFIG=/var/lib/jenkins/casc/jenkins.yaml" | sudo tee -a /etc/sysconfig/jenkins
sudo systemctl restart jenkins
```

### Extending Configuration

Edit `casc/jenkins.yaml` to add:
- Additional users and permissions
- Global credentials
- Pipeline libraries
- Plugin configurations
- Agent templates

## Python App CI/CD Pipeline

This repo includes a complete CI/CD pipeline for deploying a Python Flask application.

### Architecture

```
Developer Push → GitHub → Jenkins Pipeline → Build & Test → Deploy to Target Server
```

### Sample Application

- **Location:** `sample-app/`
- **Framework:** Flask
- **Server:** Gunicorn
- **Endpoints:**
  - `/` - Hello message with version info
  - `/health` - Health check endpoint

### 1. Setup Deployment Target Server

On your target AlmaLinux server (can be same VM as Jenkins or separate):

```sh
cd scripts
chmod +x setup-deploy-target.sh
sudo ./setup-deploy-target.sh
```

This script:
- Creates `jenkins` user for deployments
- Installs Python 3 and pip
- Creates `/opt/python-app` directory
- Installs systemd service for the app
- Opens firewall port 5000

### 2. Configure SSH Access

On the Jenkins controller:
```sh
# Generate SSH key if not exists
ssh-keygen -t rsa -b 4096 -f ~/.ssh/jenkins_deploy -N ""

# Copy public key to deployment target
ssh-copy-id -i ~/.ssh/jenkins_deploy.pub jenkins@<target-host>

# Test SSH connection
ssh -i ~/.ssh/jenkins_deploy jenkins@<target-host>
```

### 3. Add Jenkins Credentials

1. **SSH Private Key:**
   - Go to: Jenkins → Manage Jenkins → Credentials → System → Global credentials
   - Click "Add Credentials"
   - Kind: SSH Username with private key
   - ID: `deploy-ssh-key`
   - Username: `jenkins`
   - Private Key: Enter directly (paste contents of `~/.ssh/jenkins_deploy`)
   - Click "Create"

2. **Deployment Host:**
   - Add Credentials → Secret text
   - Secret: `<target-host-ip-or-hostname>`
   - ID: `deploy-host`
   - Click "Create"

### 4. Create Jenkins Pipeline Job

1. **New Item:**
   - Click "New Item"
   - Name: `python-app-pipeline`
   - Type: Pipeline
   - Click "OK"

2. **Configure Pipeline:**
   - Pipeline → Definition: "Pipeline script from SCM"
   - SCM: Git
   - Repository URL: `https://github.com/<your-org>/jenkins-lab.git` (or your repo URL)
   - Branch: `*/main`
   - Script Path: `Jenkinsfile`
   - Click "Save"

3. **Build Triggers (Optional):**
   - Check "GitHub hook trigger for GITScm polling" for automatic builds on push
   - Or configure "Poll SCM" with schedule: `H/5 * * * *` (every 5 minutes)

### 5. Pipeline Stages Explained

The `Jenkinsfile` defines these stages:

1. **Checkout** - Pulls code from Git repository
2. **Setup Python Environment** - Creates virtual environment and installs dependencies
3. **Run Tests** - Executes pytest unit tests
4. **Build Artifact** - Packages app as tarball, excludes venv and cache files
5. **Deploy to Production** - Only on `main` branch, deploys via SSH to target server

### 6. Run the Pipeline

- Click "Build Now"
- View console output to monitor progress
- On success, app will be running at `http://<target-host>:5000`

### 7. Verify Deployment

Test the deployed application:
```sh
curl http://<target-host>:5000/
curl http://<target-host>:5000/health
```

### 8. Monitor the Service

On the deployment target:
```sh
# Check service status
sudo systemctl status python-app

# View logs
sudo journalctl -u python-app -f

# Restart if needed
sudo systemctl restart python-app
```

### Manual Deployment (Without Jenkins)

If you prefer to deploy manually:
```sh
cd scripts
chmod +x deploy.sh
./deploy.sh <target-host> jenkins
```

## Reverse Proxy + TLS

Nginx is automatically configured when using Terraform. This section covers manual setup and TLS certificate configuration.

### Automatic Setup (Terraform)

When provisioning with Terraform, Nginx is pre-configured:
- Reverse proxy on port 80 → Jenkins on 8080
- WebSocket support for live logs
- Ready for TLS certificate installation

Access Jenkins at `http://<public-ip>` (via Nginx) or `http://<public-ip>:8080` (direct).

### Manual Nginx Setup

If not using Terraform, run the setup script:

### Manual Nginx Setup

If not using Terraform, run the setup script:

```sh
cd scripts
chmod +x setup-nginx-reverseproxy.sh
sudo ./setup-nginx-reverseproxy.sh
```

Or install manually:

### Install Nginx

```sh
sudo dnf -y install nginx certbot python3-certbot-nginx
```

### Configure Nginx

Create `/etc/nginx/conf.d/jenkins.conf`:

```nginx
upstream jenkins {
    server 127.0.0.1:8080;
}

server {
    listen 80;
    server_name jenkins.example.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name jenkins.example.com;
    
    ssl_certificate /etc/letsencrypt/live/jenkins.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/jenkins.example.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    
    location / {
        proxy_pass http://jenkins;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 90;
        
        # WebSocket support for live logs
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

### Obtain TLS Certificate

```sh
sudo certbot --nginx -d jenkins.example.com
sudo systemctl enable nginx
sudo systemctl restart nginx
```

### Update Jenkins URL

1. Go to: Manage Jenkins → System
2. Set "Jenkins URL" to `https://jenkins.example.com`
3. Click "Save"

### Auto-Renewal

Certbot auto-renewal is configured via systemd timer:
```sh
sudo systemctl status certbot-renew.timer
```

## Backups and Restore

Protect your Jenkins configuration, jobs, and build history.

### What to Back Up

- `/var/lib/jenkins/` (entire JENKINS_HOME) contains:
  - Job configurations
  - Build history
  - Credentials (encrypted)
  - Installed plugins
  - System configuration

### Automated Backup Script

Create `/usr/local/bin/backup-jenkins.sh`:

```bash
#!/bin/bash
set -euo pipefail

BACKUP_DIR="/var/backups/jenkins"
JENKINS_HOME="/var/lib/jenkins"
RETENTION_DAYS=7
DATE=$(date +%F)

# Create backup directory
mkdir -p ${BACKUP_DIR}

# Stop Jenkins for consistent backup (optional, can use thin backup plugin instead)
# sudo systemctl stop jenkins

# Create tarball
sudo tar czf ${BACKUP_DIR}/jenkins-home-${DATE}.tar.gz \
    --exclude=${JENKINS_HOME}/workspace \
    --exclude=${JENKINS_HOME}/war \
    --exclude=${JENKINS_HOME}/cache \
    ${JENKINS_HOME}

# Restart Jenkins
# sudo systemctl start jenkins

# Remove old backups
find ${BACKUP_DIR} -name 'jenkins-home-*.tar.gz' -mtime +${RETENTION_DAYS} -delete

echo "Backup completed: ${BACKUP_DIR}/jenkins-home-${DATE}.tar.gz"
```

### Schedule Daily Backups

```sh
sudo chmod +x /usr/local/bin/backup-jenkins.sh
sudo crontab -e
# Add this line:
0 2 * * * /usr/local/bin/backup-jenkins.sh >> /var/log/jenkins-backup.log 2>&1
```

### Offsite Backup to S3

Add to backup script:
```bash
aws s3 sync ${BACKUP_DIR} s3://your-bucket/jenkins-backups/ \
    --exclude "*" --include "jenkins-home-*.tar.gz"
```

Or Azure Blob:
```bash
az storage blob upload-batch \
    --source ${BACKUP_DIR} \
    --destination jenkins-backups \
    --account-name youraccount
```

### Restore Procedure

1. **Stop Jenkins:**
   ```sh
   sudo systemctl stop jenkins
   ```

2. **Restore from backup:**
   ```sh
   sudo rm -rf /var/lib/jenkins/*
   sudo tar xzf /var/backups/jenkins/jenkins-home-2026-01-12.tar.gz -C /
   sudo chown -R jenkins:jenkins /var/lib/jenkins
   ```

3. **Start Jenkins:**
   ```sh
   sudo systemctl start jenkins
   ```

4. **Verify:**
   - Check that jobs and configurations are present
   - May need to reinstall plugins if plugin directory was corrupted

### Alternative: ThinBackup Plugin

Install the ThinBackup plugin for online backups:
1. Manage Jenkins → Plugins → Available → Search "ThinBackup"
2. Install and restart
3. Configure backup location and schedule
4. Excludes build artifacts, only backs up configs

## Best Practices

### Security

- Use HTTPS/TLS for all access
- Enable CSRF protection (default)
- Use role-based access control (install Role-based Authorization Strategy plugin)
- Store secrets in Credentials plugin, never in code
- Regularly update Jenkins and plugins
- Limit controller executors (0-2), use agents for builds

### Maintenance

- Monitor disk space (`/var/lib/jenkins` can grow large)
- Clean old builds regularly (configure discard policy per job)
- Test plugin updates in non-production first
- Keep backup of working state before major changes
- Document custom configurations in JCasC YAML

### Agent Configuration

For scalability, add build agents:
1. Manage Jenkins → Nodes → New Node
2. Configure SSH/JNLP connection
3. Set labels for targeting specific builds
4. Configure retention strategy (demand-based recommended)

### Monitoring

- Install Prometheus plugin for metrics
- Set up health checks monitoring `/health` endpoint
- Configure email/Slack notifications for build failures
- Review system logs: `sudo journalctl -u jenkins -f`

## Troubleshooting

### Jenkins Won't Start

```sh
# Check service status
sudo systemctl status jenkins

# View logs
sudo journalctl -u jenkins -n 50

# Check Java version
java -version  # Should be 17+

# Verify file permissions
sudo chown -R jenkins:jenkins /var/lib/jenkins
```

### Pipeline Fails on Deploy Stage

- Verify SSH connectivity: `ssh jenkins@<target-host>`
- Check credentials in Jenkins match SSH key
- Ensure deploy host is reachable
- Check firewall allows SSH (port 22)

### App Not Starting After Deployment

```sh
# On target server
sudo systemctl status python-app
sudo journalctl -u python-app -n 50

# Common issues:
# - Missing Python dependencies
# - Port 5000 already in use
# - Permissions on /opt/python-app
```

### Plugin Installation Fails

- Check internet connectivity from Jenkins server
- Verify proxy settings if behind corporate firewall
- Try manual plugin upload (.hpi file)
- Check disk space

## Additional Resources

- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [JCasC Plugin](https://github.com/jenkinsci/configuration-as-code-plugin)
- [Pipeline Syntax Reference](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [Plugin Index](https://plugins.jenkins.io/)

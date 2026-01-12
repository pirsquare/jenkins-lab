# Jenkins Lab

Reference notes and starter commands to spin up Jenkins quickly across common targets (cloud VMs, Docker, Kubernetes). Copy/paste the sections you need and adjust resource names and regions as appropriate.

## Targets at a Glance
- Docker (single host): Fastest path for local trials or small teams.
- Kubernetes: Use Helm for HA-ready installs; good for staging/prod.
- Linux VM (AlmaLinux): Straightforward package install; good for single-node controllers.
- AWS EC2 / Azure VM / GCP Compute Engine: Same VM steps plus provider-specific networking/storage notes.

## Prerequisites
- 2 vCPU / 4 GB RAM minimum for the controller; more for larger workloads.
- Ingress open on 8080 (or 80/443 with a reverse proxy); allow SSH/WinRM for maintenance.
- Java 17+ (Temurin or OpenJDK). AlmaLinux steps below install OpenJDK 17.
- Storage: persistent volume for /var/jenkins_home (or host bind for Docker).

## Quick Start

### Docker (Fastest)
```sh
docker run -d -p 8080:8080 -p 50000:50000 -v jenkins_home:/var/jenkins_home jenkins/jenkins:lts
```
Get admin password: `docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword`

**→ See [JENKINS.md](JENKINS.md) for complete installation and configuration instructions**

### AlmaLinux VM
See [JENKINS.md](JENKINS.md#almalinux-vm) for package installation steps.

### Kubernetes (Helm)
See [JENKINS.md](JENKINS.md#kubernetes-helm) for Helm chart installation.

## Architecture

**AWS:**
- VPC with public subnets across 2 AZs
- Security group allowing SSH/HTTP/HTTPS and optional direct 8080
- Nginx reverse proxy on the instance for HTTP/HTTPS
- EBS encrypted root volume

**Azure:**
- VNet with VM subnet
- Network Security Group allowing SSH/HTTP/HTTPS and 8080
- Nginx reverse proxy on the VM for HTTP/HTTPS
- Premium SSD storage

**GCP:**
- VPC with regional subnet
- Firewall allowing SSH/HTTP/HTTPS and 8080
- Nginx reverse proxy on the instance for HTTP/HTTPS
- SSD persistent disks

## Post-Install Basics
- Complete the web wizard, install recommended plugins, and create the admin user.
- Create a dedicated agent network and limit controller executors (e.g., set to 0–2) to encourage agents.
- Back up JENKINS_HOME (plugins, jobs, secrets) and store credentials via the Jenkins credentials store.

## Maintenance Tips
- Keep controller updated (LTS preferred). Test plugins in non-prod before upgrading prod.
- Use Configuration as Code (JCasC) for repeatable setup; pin plugin versions.
- Enable periodic backups of the Jenkins home directory and any external secrets.

## Infrastructure as Code (Terraform)

Complete infrastructure provisioning including VPC, networking, security groups, and Nginx reverse proxy.

### What's Included

- **Networking:** VPC, subnets, route tables, internet gateways
- **Security:** Network security groups, firewall rules with HTTP/HTTPS access
- **Reverse Proxy:** Nginx auto-configured for Jenkins with TLS support
- **Compute:** AlmaLinux VMs with Jenkins and Nginx auto-installed
- **Monitoring:** Instance monitoring and health checks

### Quick Start

**AWS:**
```sh
cd terraform/aws
terraform init
terraform apply
```

**Azure:**
```sh
cd terraform/azure
terraform apply -var="ssh_public_key=~/.ssh/id_rsa.pub"
```

**GCP:**
```sh
cd terraform/gcp
terraform apply -var="project=your-gcp-project-id"
```

### Outputs

Each Terraform configuration provides:
- Public IPs
- HTTP/HTTPS URLs (via Nginx reverse proxy)
- Direct access URLs (port 8080)
- SSH commands
- Next steps for TLS configuration

Run `terraform output` to view all outputs after provisioning.

## Jenkins Configuration as Code (JCasC)

Example configuration in `casc/jenkins.yaml` seeds admin user and folder structure.

**→ See [JENKINS.md](JENKINS.md#configuration-as-code-jcasc) for JCasC setup and usage**

## Reverse Proxy & TLS

Nginx is automatically configured as a reverse proxy when using Terraform. For HTTPS/TLS:

**→ See [JENKINS.md](JENKINS.md#reverse-proxy--tls) for TLS certificate setup with Let's Encrypt**

## Backups and Restore

Critical to back up `/var/lib/jenkins` (jobs, configs, credentials, build history).

**→ See [JENKINS.md](JENKINS.md#backups-and-restore) for automated backup scripts and restore procedures**

## Python App CI/CD Example

Includes a complete Flask application with automated Jenkins pipeline:
- **Sample App:** `sample-app/` - Flask + Gunicorn with `/` and `/health` endpoints
- **Pipeline:** `Jenkinsfile` - automated test, build, and deploy
- **Scripts:** `scripts/` - deployment automation and systemd service

**Quick Deploy:**
```sh
# Setup target server
cd scripts && sudo ./setup-deploy-target.sh

# Manual deploy (or use Jenkins pipeline)
./deploy.sh <target-host> jenkins
```

**→ See [JENKINS.md](JENKINS.md#python-app-cicd-pipeline) for complete CI/CD setup guide**

## Future Improvements
Multi-stage Docker builds, Kubernetes manifests, Helm charts for the Python app, and monitoring integration (Prometheus/Grafana).

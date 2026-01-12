# Jenkins Lab

Reference notes and starter commands to spin up Jenkins quickly across common targets (cloud VMs, Docker, Kubernetes). Copy/paste the sections you need and adjust resource names and regions as appropriate.

## Targets at a Glance
- **Docker (single host)**: Fastest path for local trials or small teams.
- **Kubernetes**: Use Helm for HA-ready installs; good for staging/prod.
- **Linux VM (Ubuntu/Debian)**: Straightforward package install; good for single-node controllers.
- **AWS EC2 / Azure VM / GCP Compute Engine**: Same VM steps plus provider-specific networking/storage notes.

## Prerequisites
- 2 vCPU / 4 GB RAM minimum for the controller; more for larger workloads.
- Ingress open on 8080 (or 80/443 with a reverse proxy); allow SSH/WinRM for maintenance.
- Java 17+ (Temurin or OpenJDK). Install steps below cover this for Debian/Ubuntu.
- Storage: persistent volume for `/var/jenkins_home` (or host bind for Docker).

## Docker (quickest)
```sh
docker pull jenkins/jenkins:lts
docker run -d \
	--name jenkins \
	-p 8080:8080 -p 50000:50000 \
	-v jenkins_home:/var/jenkins_home \
	jenkins/jenkins:lts
```
View admin password: `docker exec -it jenkins cat /var/jenkins_home/secrets/initialAdminPassword`

## Kubernetes (Helm)
```sh
helm repo add jenkins https://charts.jenkins.io
helm repo update
helm install jenkins jenkins/jenkins \
	--namespace jenkins --create-namespace \
	--set controller.serviceType=LoadBalancer
```
- Get admin password: `kubectl exec -n jenkins -it deploy/jenkins -- cat /var/jenkins_home/secrets/initialAdminPassword`
- For ingress: set `controller.ingress.enabled=true` and provide host/path annotations.

## Linux VM (Ubuntu/Debian)
```sh
sudo apt update
sudo apt install -y fontconfig openjdk-17-jre
wget -q -O - https://pkg.jenkins.io/debian/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt update
sudo apt install -y jenkins
sudo systemctl enable --now jenkins
sudo systemctl status jenkins
```
- Admin password: `sudo cat /var/lib/jenkins/secrets/initialAdminPassword`
- Default port 8080; adjust firewall (`ufw allow 8080/tcp`).

## Cloud VM Notes
- **AWS EC2**: Use a security group allowing 22 and 8080/443; attach an EBS volume for `/var/lib/jenkins` if you want data durability beyond root disk. Consider an ALB/NLB terminating TLS.
- **Azure VM**: NSG rules for 22 and 8080/443; add a data disk and mount to `/var/lib/jenkins`; optionally front with Application Gateway for TLS.
- **GCP Compute Engine**: VPC firewall for 22 and 8080/443; optional persistent disk for `/var/lib/jenkins`; HTTPS Load Balancer if exposing publicly.

## Post-Install Basics
- Complete the web wizard, install recommended plugins, and create the admin user.
- Create a dedicated agent network and limit controller executors (e.g., set to 0–2) to encourage agents.
- Back up `JENKINS_HOME` (plugins, jobs, secrets) and store credentials via the Jenkins credentials store.

## Maintenance Tips
- Keep controller updated (LTS preferred). Test plugins in non-prod before upgrading prod.
- Use Configuration as Code (JCasC) for repeatable setup; pin plugin versions.
- Enable periodic backups of the Jenkins home directory and any external secrets.

## Contributing
Future improvements: provider-specific Terraform/Terragrunt samples, JCasC examples, and hardened reverse-proxy configs (Nginx/Traefik/Caddy).


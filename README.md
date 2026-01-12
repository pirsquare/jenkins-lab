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

## Linux VM (AlmaLinux)
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

## Cloud VM Notes
- AWS EC2: Use a security group allowing 22 and 8080/443; attach an EBS volume for /var/lib/jenkins if you want data durability beyond root disk. Consider an ALB/NLB terminating TLS.
- Azure VM: NSG rules for 22 and 8080/443; add a data disk and mount to /var/lib/jenkins; optionally front with Application Gateway for TLS.
- GCP Compute Engine: VPC firewall for 22 and 8080/443; optional persistent disk for /var/lib/jenkins; HTTPS Load Balancer if exposing publicly.

## Post-Install Basics
- Complete the web wizard, install recommended plugins, and create the admin user.
- Create a dedicated agent network and limit controller executors (e.g., set to 0–2) to encourage agents.
- Back up JENKINS_HOME (plugins, jobs, secrets) and store credentials via the Jenkins credentials store.

## Maintenance Tips
- Keep controller updated (LTS preferred). Test plugins in non-prod before upgrading prod.
- Use Configuration as Code (JCasC) for repeatable setup; pin plugin versions.
- Enable periodic backups of the Jenkins home directory and any external secrets.

## Infrastructure as Code (Terraform)
Starter configs live under terraform/ and point to the reusable cloud-init script at terraform/cloud-init/jenkins-almalinux.sh.

- AWS: terraform/aws/main.tf
- Azure: terraform/azure/main.tf
- GCP: terraform/gcp/main.tf

Update variables (region, project, key paths, instance size) before `terraform init && terraform apply`.

## Jenkins Configuration as Code (JCasC)
See casc/jenkins.yaml for a JCasC starter that seeds an admin user and an example folder.
Run with Docker: `docker run -d -p 8080:8080 -v $PWD/casc:/var/jenkins_home/casc jenkins/jenkins:lts-jdk17 --argumentsRealm.passwd.admin=change-me --argumentsRealm.roles.admin=admin --config /var/jenkins_home/casc/jenkins.yaml`

## Reverse Proxy + TLS (Nginx)
Terminate TLS on port 443 and proxy to Jenkins on 8080.
```nginx
server {
    listen 80;
    server_name jenkins.example.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name jenkins.example.com;
    ssl_certificate     /etc/letsencrypt/live/jenkins.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/jenkins.example.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```
Test locally with `curl -I https://jenkins.example.com` and ensure Jenkins Manage Jenkins -> Configure System -> Jenkins URL matches the HTTPS URL.

## Backups and Restore
- What to back up: /var/jenkins_home (jobs, plugins, secrets, credentials). For Docker, back up the named volume; for Kubernetes, back up the PVC.
- Simple nightly backup (controller):
  ```sh
  sudo tar czf /var/backups/jenkins-home-$(date +%F).tgz /var/jenkins_home
  find /var/backups -name "jenkins-home-*.tgz" -mtime +7 -delete
  ```
- Offsite: sync to cloud storage (S3/Blob/GS) via `aws s3 sync /var/backups s3://your-bucket/jenkins/` (or provider equivalent).
- Restore: stop Jenkins, restore the archive to /var/jenkins_home, ensure ownership jenkins:jenkins, then start Jenkins. For containers, mount the restored directory/volume and restart.

## Contributing
Future improvements: provider-specific Terraform/Terragrunt samples, JCasC examples, and hardened reverse-proxy configs (Nginx/Traefik/Caddy).

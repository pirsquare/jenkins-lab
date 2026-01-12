# GCP Jenkins Infrastructure

Terraform configuration for deploying Jenkins on Google Compute Engine with Nginx reverse proxy.

## Architecture

- **VPC Network**: Custom VPC with regional subnet (10.20.1.0/24)
- **Firewall Rules**: Allows SSH (22), HTTP (80), HTTPS (443), Jenkins (8080)
- **Compute**: AlmaLinux 9 instance with Jenkins + Nginx pre-installed
- **Storage**: 50GB SSD persistent disk
- **Networking**: Static external IP address
- **Security**: Shielded VM with Secure Boot enabled

## Prerequisites

- Google Cloud SDK installed and authenticated (`gcloud auth login`)
- Terraform >= 1.0
- GCP project with Compute Engine API enabled

## Quick Start

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan -var="project=your-gcp-project-id"

# Deploy infrastructure
terraform apply -var="project=your-gcp-project-id"

# View outputs
terraform output
```

## Configuration Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `project` | GCP project ID | - | Yes |
| `region` | GCP region | `asia-southeast1` | No |
| `zone` | GCP zone | `asia-southeast1-a` | No |
| `machine_type` | Instance machine type | `e2-medium` | No |

## Custom Configuration

```bash
# Custom region and machine type
terraform apply \
  -var="project=my-project" \
  -var="region=us-west1" \
  -var="zone=us-west1-a" \
  -var="machine_type=e2-standard-2"
```

## Outputs

- `jenkins_public_ip` - External IP address
- `jenkins_http_url` - HTTP URL via Nginx (port 80)
- `jenkins_https_url` - HTTPS URL (after TLS setup)
- `jenkins_direct_url` - Direct Jenkins access (port 8080)
- `ssh_command` - gcloud SSH connection command
- `next_steps` - Post-deployment instructions

## Post-Deployment

1. Wait 3-5 minutes for cloud-init to complete
2. SSH to instance: `gcloud compute ssh jenkins-controller --zone=asia-southeast1-a`
3. Get admin password: `sudo cat /var/lib/jenkins/secrets/initialAdminPassword`
4. Access Jenkins: Check `jenkins_http_url` output
5. Configure TLS: See [JENKINS.md](../../JENKINS.md#reverse-proxy--tls)

## Cleanup

```bash
terraform destroy -var="project=your-gcp-project-id"
```

## Security Considerations

- Firewall rules allow worldwide access on 22, 80, 443, 8080 - restrict via `source_ranges`
- Shielded VM with Secure Boot enabled by default
- Consider using Identity-Aware Proxy (IAP) for SSH access
- Enable VPC Flow Logs for network monitoring
- Use Cloud Armor for DDoS protection

## Troubleshooting

**View serial console output:**
```bash
gcloud compute instances get-serial-port-output jenkins-controller --zone=asia-southeast1-a
```

**SSH to instance:**
```bash
gcloud compute ssh jenkins-controller --zone=asia-southeast1-a
```

**Cloud-init logs:**
```bash
sudo tail -f /var/log/cloud-init-output.log
```

**Jenkins logs:**
```bash
sudo journalctl -u jenkins -f
```

**Nginx logs:**
```bash
sudo tail -f /var/log/nginx/jenkins.access.log
sudo tail -f /var/log/nginx/jenkins.error.log
```

## Cost Optimization

- Use `e2-micro` or `e2-small` for dev/test environments
- Consider preemptible VMs for non-critical workloads (add `scheduling.preemptible = true`)
- Use committed use discounts for production workloads
- Enable startup/shutdown schedules for non-production instances

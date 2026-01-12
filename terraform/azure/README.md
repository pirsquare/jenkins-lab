# Azure Jenkins Infrastructure

Terraform configuration for deploying Jenkins on Azure VM with Nginx reverse proxy.

## Architecture

- **Virtual Network**: 10.10.0.0/16 with VM subnet (10.10.1.0/24)
- **Network Security Group**: Allows SSH (22), HTTP (80), HTTPS (443), Jenkins (8080)
- **Compute**: AlmaLinux 9 VM with Jenkins + Nginx pre-installed
- **Storage**: Premium SSD managed disk
- **Networking**: Public IP with static allocation

## Prerequisites

- Azure CLI logged in (`az login`)
- Terraform >= 1.0
- SSH public key for VM access

## Quick Start

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan -var="ssh_public_key=~/.ssh/id_rsa.pub"

# Deploy infrastructure
terraform apply -var="ssh_public_key=~/.ssh/id_rsa.pub"

# View outputs
terraform output
```

## Configuration Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `location` | Azure region | `southeastasia` |
| `admin_username` | VM admin username | `azureuser` |
| `ssh_public_key` | Path to SSH public key | `~/.ssh/id_rsa.pub` |
| `vm_size` | Azure VM size | `Standard_B2ms` |

## Custom Configuration

```bash
# Custom region and VM size
terraform apply \
  -var="ssh_public_key=~/.ssh/id_rsa.pub" \
  -var="location=westus2" \
  -var="vm_size=Standard_D2s_v3"

# Custom admin username
terraform apply \
  -var="ssh_public_key=~/.ssh/id_rsa.pub" \
  -var="admin_username=jenkins"
```

## Outputs

- `jenkins_public_ip` - Public IP address
- `jenkins_http_url` - HTTP URL via Nginx (port 80)
- `jenkins_https_url` - HTTPS URL (after TLS setup)
- `jenkins_direct_url` - Direct Jenkins access (port 8080)
- `ssh_command` - SSH connection command
- `next_steps` - Post-deployment instructions

## Post-Deployment

1. Wait 3-5 minutes for cloud-init to complete
2. SSH to VM: `terraform output -raw ssh_command | bash`
3. Get admin password: `sudo cat /var/lib/jenkins/secrets/initialAdminPassword`
4. Access Jenkins: Check `jenkins_http_url` output
5. Configure TLS: See [JENKINS.md](../../JENKINS.md#reverse-proxy--tls)

## Cleanup

```bash
terraform destroy -var="ssh_public_key=~/.ssh/id_rsa.pub"
```

## Security Considerations

- NSG allows worldwide access on 22, 80, 443, 8080 - restrict as needed
- Use Azure Bastion for enhanced SSH security
- Consider Azure Key Vault for secrets management
- Enable Azure Monitor for VM metrics and alerts

## Troubleshooting

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

- Use `Standard_B2s` for dev/test environments
- Consider Azure Reserved VM Instances for production
- Use Azure Spot VMs for non-critical workloads
- Enable auto-shutdown for non-production VMs

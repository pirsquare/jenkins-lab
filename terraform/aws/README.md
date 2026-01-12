# AWS Jenkins Infrastructure

Terraform configuration for deploying Jenkins on AWS EC2 with Nginx reverse proxy.

## Architecture

- **VPC**: 10.0.0.0/16 with 2 public subnets across availability zones
- **Security Group**: Allows SSH (22), HTTP (80), HTTPS (443), Jenkins direct access (8080)
- **Compute**: AlmaLinux 9 EC2 instance with Jenkins + Nginx pre-installed
- **Storage**: 50GB encrypted EBS volume (gp3)
- **Networking**: Internet Gateway, public route table, static subnet assignments

## Prerequisites

- AWS CLI configured with credentials
- Terraform >= 1.0
- SSH key pair for instance access

## Quick Start

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Deploy infrastructure
terraform apply

# View outputs
terraform output
```

## Configuration Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `region` | AWS region | `ap-southeast-1` |
| `instance_type` | EC2 instance type | `t3.medium` |
| `key_name` | SSH key pair name | `jenkins-key` |
| `public_key_path` | Path to SSH public key | `~/.ssh/id_rsa.pub` |
| `vpc_cidr` | VPC CIDR block | `10.0.0.0/16` |

## Custom Configuration

```bash
# Custom region and instance type
terraform apply \
  -var="region=us-west-2" \
  -var="instance_type=t3.large"

# Custom VPC CIDR
terraform apply -var="vpc_cidr=10.1.0.0/16"
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
2. SSH to instance: `terraform output -raw ssh_command | bash`
3. Get admin password: `sudo cat /var/lib/jenkins/secrets/initialAdminPassword`
4. Access Jenkins: Check `jenkins_http_url` output
5. Configure TLS: See [JENKINS.md](../../JENKINS.md#reverse-proxy--tls)

## Cleanup

```bash
terraform destroy
```

## Security Considerations

- Security group allows worldwide access on 22, 80, 443, 8080 - restrict as needed
- EBS encryption enabled by default
- IMDSv2 required for instance metadata
- Consider using AWS Systems Manager Session Manager instead of SSH

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

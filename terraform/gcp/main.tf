provider "google" {
  project = var.project
  region  = var.region
}

variable "project" { type = string }
variable "region" { type = string; default = "asia-southeast1" }
variable "zone" { type = string; default = "asia-southeast1-a" }
variable "machine_type" { type = string; default = "e2-medium" }

# VPC Network
resource "google_compute_network" "vpc" {
  name                    = "jenkins-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "jenkins-subnet"
  ip_cidr_range = "10.20.1.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}

# Firewall Rules
resource "google_compute_firewall" "jenkins" {
  name    = "jenkins-allow-web"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "8080"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["jenkins"]
}

# Static IP Address
resource "google_compute_address" "jenkins" {
  name   = "jenkins-ip"
  region = var.region
}

# Instance Template / VM
resource "google_compute_instance" "jenkins" {
  name         = "jenkins-controller"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["jenkins"]

  boot_disk {
    initialize_params {
      image = "projects/almalinux-cloud/global/images/family/almalinux-9"
      size  = 50
      type  = "pd-ssd"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet.id
    access_config {
      nat_ip = google_compute_address.jenkins.address
    }
  }

  metadata = {
    user-data = templatefile("${path.module}/../cloud-init/jenkins-almalinux.sh", {})
  }

  shielded_instance_config {
    enable_secure_boot = true
  }
}

# Outputs
output "jenkins_public_ip" {
  description = "External IP of Jenkins instance"
  value       = google_compute_address.jenkins.address
}

output "jenkins_http_url" {
  description = "HTTP URL to Jenkins (via Nginx reverse proxy)"
  value       = "http://${google_compute_address.jenkins.address}"
}

output "jenkins_https_url" {
  description = "HTTPS URL to Jenkins (configure TLS in Nginx)"
  value       = "https://${google_compute_address.jenkins.address}"
}

output "jenkins_direct_url" {
  description = "Direct access URL to Jenkins (bypass Nginx)"
  value       = "http://${google_compute_address.jenkins.address}:8080"
}

output "ssh_command" {
  description = "SSH command to connect to Jenkins instance"
  value       = "gcloud compute ssh jenkins-controller --zone=${var.zone}"
}

output "next_steps" {
  description = "Next steps after provisioning"
  value = <<-EOT
    1. Wait 3-5 minutes for Jenkins and Nginx to install
    2. SSH: gcloud compute ssh jenkins-controller --zone=${var.zone}
    3. Get admin password: sudo cat /var/lib/jenkins/secrets/initialAdminPassword
    4. Access Jenkins via Nginx: http://${google_compute_address.jenkins.address}
    5. Direct Jenkins access: http://${google_compute_address.jenkins.address}:8080
    6. For HTTPS: Configure TLS certificate in /etc/nginx/conf.d/jenkins.conf
  EOT
}

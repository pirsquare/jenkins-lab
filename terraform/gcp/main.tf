provider "google" {
  project = var.project
  region  = var.region
}

variable "project" { type = string }
variable "region"  { type = string default = "us-central1" }
variable "zone"    { type = string default = "us-central1-a" }

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

resource "google_compute_firewall" "fw" {
  name    = "jenkins-fw"
  network = google_compute_network.vpc.name
  allow { protocol = "tcp" ports = ["22", "8080", "443"] }
  direction    = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_instance" "jenkins" {
  name         = "jenkins-controller"
  machine_type = "e2-medium"
  zone         = var.zone
  boot_disk {
    initialize_params {
      image = "projects/almalinux-cloud/global/images/family/almalinux-9"
      size  = 50
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.subnet.id
    access_config {}
  }
  metadata = { user-data = file("${path.module}/../cloud-init/jenkins-almalinux.sh") }
}

# Use Terraform with GCP - Google Cloud Platform
#
# Made by Michael Kravtsiv for Shani's home test for new employeer in DevOps Team
#
#-----------------------------------------------------------

terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "4.51.0"
    }
  }
}

provider "google" {
  #credentials = file("mygcp-creds.json")
  project     = "dgt-gcp-cgov-d-michaelk"
  region      = "me-west1"
  zone        = "me-west1-a"
}

# Create VPC
resource "google_compute_network" "vpc_network" {
  name                    = "michaelk-shani-home-test"
  auto_create_subnetworks = false
}

# Create subnet-1 within the VPC
resource "google_compute_subnetwork" "subnet-1" {
  name          = "subnet-1"
  ip_cidr_range = "10.0.0.0/8"
  network       = google_compute_network.vpc_network.id
  region        = "me-west1"
}

# Create Firewall Rules for the VPC
resource "google_compute_firewall" "allow_internal" {
  name    = "home-test-FW-rule"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["80", "22", "443", "3389"]
  }

  source_ranges = ["0.0.0.0/0", "11.0.0.0/8"]
}

# Create Ubuntu VM
resource "google_compute_instance" "ubuntu_vm" {
  name         = "ubuntu"
  machine_type = "e2-medium"
  zone         = "me-west1-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.subnet-1.id
    #access_config {}
  }
  metadata_startup_script = <<EOF
#!/bin/bash
sudo python3 -m http.server 80
EOF

  service_account {
    email  = "d-michaelk-iac@dgt-gcp-cgov-d-michaelk.iam.gserviceaccount.com"
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
}

# Create additional disk for Windows VM
resource "google_compute_disk" "windows_additional_disk" {
  name  = "additional-windows-disk"
  size  = 20
  type  = "pd-standard"
  zone  = "me-west1-a"
}

# Create Windows VM and attach the additional disk in subnet-1
resource "google_compute_instance" "windows_vm" {
  name         = "windows-server-1"
  machine_type = "e2-medium"
  zone         = "me-west1-a"

  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2019"
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.subnet-1.id
    #access_config {}
  }

  attached_disk {
    source = google_compute_disk.windows_additional_disk.id
  }

  service_account {
    email  = "d-michaelk-iac@dgt-gcp-cgov-d-michaelk.iam.gserviceaccount.com"
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
  
  tags = ["windows-server-1"]
}

# Create a GCS bucket
resource "google_storage_bucket" "bucket" {
  name                        = "michaelk-shani-test"
  location                    = "me-west1"
  storage_class               = "REGIONAL"
  uniform_bucket_level_access = true
  versioning {
    enabled = true
  }
  force_destroy = true
}

# Allow VMs to access the bucket
resource "google_project_iam_member" "bucket_access_ubuntu" {
  project = "dgt-gcp-cgov-d-michaelk"
  role    = "roles/storage.objectCreator"
  member  = "serviceAccount:${google_compute_instance.ubuntu_vm.service_account[0].email}"
}

resource "google_project_iam_member" "bucket_access_windows" {
  project = "dgt-gcp-cgov-d-michaelk"
  role    = "roles/storage.objectCreator"
  member  = "serviceAccount:${google_compute_instance.windows_vm.service_account[0].email}"
}

# Create subnet-2
resource "google_compute_subnetwork" "subnet-2" {
  name          = "subnet-2"
  ip_cidr_range = "11.0.0.0/8"
  region        = "me-west1"
  network       = google_compute_network.vpc_network.id
}

# Create a new Windows Server 2019 VM in the subnet-2
resource "google_compute_instance" "windows-server-2" {
  name         = "windows-server-2"
  machine_type = "e2-medium"
  zone         = "me-west1-a"

  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2019"
    }
  }

  network_interface {
    network    = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.subnet-2.id
    #access_config {}
  }

  service_account {
    email  = "d-michaelk-iac@dgt-gcp-cgov-d-michaelk.iam.gserviceaccount.com"
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  tags = ["windows-server-2"]

}


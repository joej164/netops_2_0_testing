// Configure the Google Cloud provider
provider "google" {
 credentials = file("credentials.json")
 project     = "jacobs-netops20-initialtesting"
 region      = "us-west1"
}

// Terraform plugin for creating random ids
resource "random_id" "instance_id" {
 byte_length = 8
}

resource "google_compute_network" "student-1" {
    name = "student-1"
    timeouts {
        create = "4m"
        delete = "4m"
    }
    auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "student-1-subnet" {
    name = "student-1-subnet"
    ip_cidr_range = "10.0.0.0/24"
    region = "us-west1"
    network = google_compute_network.student-1.name
    timeouts {
        create = "4m"
        delete = "4m"
    }
}


resource "google_compute_firewall" "student-1" {
    name = "student-1-firewall"
    network = google_compute_network.student-1.name
    timeouts {
        create = "4m"
        delete = "4m"
    }
    allow {
        protocol = "icmp"
    }

    allow {
        protocol = "tcp"
        ports = ["22"]
    }
}

resource "google_deployment_manager_deployment" "deployment" {
  name = "my-deployment"

  target {
    config {
      content = file("dm.yaml")
    }
  }

  timeouts {
    create = "4m"
    delete = "4m"
  }

  labels {
    key = "foo"
    value = "bar"
  }
  depends_on = [google_compute_subnetwork.student-1-subnet]
}


resource "google_deployment_manager_deployment" "csr-deployment" {
  name = "my-csr-deployment"

  target {
    config {
      content = file("csr1000v.yaml")
    }
  }

  timeouts {
    create = "4m"
    delete = "4m"
  }

  labels {
    key = "foo"
    value = "bar"
  }
  depends_on = [google_compute_subnetwork.student-1-subnet]
}


// A single Google Cloud Engine instance
resource "google_compute_instance" "student-1-jump" {
 name         = "jump-server-vm-student-1"
 machine_type = "f1-micro"
 zone         = "us-west1-a"
 timeouts {
    create = "4m"
    delete = "4m"
 } 
 boot_disk {
   initialize_params {
     image = "ubuntu-os-cloud/ubuntu-2004-lts"
   }
 }
 metadata = {
   ssh-keys = "joej:${file("~/.ssh/id_rsa.pub")}"
  }

 // Install Ansible, clone repo, and configure server 
 metadata_startup_script = "sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get install ansible -y"

 network_interface {
   subnetwork = google_compute_subnetwork.student-1-subnet.name
   network_ip = "10.0.0.250"
   access_config {
     // Include this section to give the VM an external ip address
   }
 }
}

output "ip" {
 value = google_compute_instance.student-1-jump.network_interface.0.access_config.0.nat_ip
}

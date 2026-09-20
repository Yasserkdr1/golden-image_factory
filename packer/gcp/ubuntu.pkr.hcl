packer {
  required_plugins {
    googlecompute = {
      version = ">= 1.2.1"
      source  = "github.com/hashicorp/googlecompute"
    }

    ansible = {
      version = "~> 1"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

source "googlecompute" "ubuntu" {
  project_id       = var.project_id
  zone             = var.zone
  use_iap          = true
  omit_external_ip = false
  use_internal_ip  = false

  source_image_family     = var.source_image_family
  source_image_project_id = [var.source_image_project_id]

  machine_type = var.machine_type

  ssh_username = var.ssh_username
  ssh_timeout  = "20m"

  image_name = "${var.image_name}-${formatdate("YYYYMMDD-hhmmss", timestamp())}"

  image_description = "Ubuntu 24.04 Golden Image hardened with Ansible"

  disk_size = 20
  disk_type = "pd-balanced"
}

build {
  name = "ubuntu-golden-image"

  sources = [
    "source.googlecompute.ubuntu"
  ]

  # -----------------------------------------------------------------------
  # Ansible hardening
  # -----------------------------------------------------------------------

  provisioner "ansible" {
    playbook_file = "${path.root}/../../ansible/site.yml"
    groups        = ["servers"]
    user          = var.ssh_username

    ansible_env_vars = [
      "ANSIBLE_HOST_KEY_CHECKING=False",
      "ANSIBLE_ROLES_PATH=${path.root}/../../ansible/roles"
    ]

    extra_arguments = [
      "--extra-vars",
      "packages_full_upgrade_enabled=true grub_hardening_enabled=false grub_password_enabled=false mount_hardening_separate_filesystems_enabled=false time_sync_backend=chrony"
    ]
  }

  # -----------------------------------------------------------------------
  # Reboot after hardening
  # -----------------------------------------------------------------------

  provisioner "shell" {
    inline = [
      "sudo /usr/sbin/reboot"
    ]

    expect_disconnect = true
  }

  provisioner "shell" {
    pause_before = "60s"

    inline = [
      "echo 'GCP VM available after reboot'",
      "uptime -s"
    ]
  }

  # -----------------------------------------------------------------------
  # Ansible verification
  # -----------------------------------------------------------------------

  provisioner "ansible" {
    playbook_file = "${path.root}/../../ansible/tests/verify.yml"
    groups        = ["servers"]
    user          = var.ssh_username
    ansible_env_vars = [
      "ANSIBLE_HOST_KEY_CHECKING=False",
    ]

    extra_arguments = [
      "--extra-vars",
      "@${path.root}/../../ansible/tests/vars/cloud.yml",
      "--extra-vars",
      "image_platform=cloud"
    ]
  }

  # -----------------------------------------------------------------------
  # OpenSCAP
  # -----------------------------------------------------------------------

  provisioner "file" {
    source      = "${path.root}/../../compliance/openscap/ssg-ubuntu2404-ds.xml"
    destination = "/tmp/ssg-ubuntu2404-ds.xml"
  }

  provisioner "shell" {
    script = "${path.root}/../../compliance/openscap/check-compliance.sh"

    execute_command = "sudo bash '{{ .Path }}'"
  }

  # -----------------------------------------------------------------------
  # Lynis
  # -----------------------------------------------------------------------

  provisioner "shell" {
    script = "${path.root}/../../compliance/lynis/check-score.sh"

    execute_command = "sudo env MINIMUM_SCORE=80 bash '{{ .Path }}'"
  }

  # -----------------------------------------------------------------------
  # Allow Packer to download compliance reports
  # -----------------------------------------------------------------------

  provisioner "shell" {
    inline = [
      "sudo chown -R ${var.ssh_username}:${var.ssh_username} /tmp/golden-image-validation"
    ]
  }

  provisioner "file" {
    source      = "/tmp/golden-image-validation/"
    destination = "${path.root}/reports/"
    direction   = "download"
  }

  # -----------------------------------------------------------------------
  # Cleanup / sealing
  # -----------------------------------------------------------------------

  provisioner "shell" {
    script = "${path.root}/../../scripts/cleanup-image.sh"

    execute_command = "sudo bash '{{ .Path }}'"
  }

  provisioner "shell" {
    script = "${path.root}/../../scripts/seal-image-gcp.sh"

    execute_command = "sudo bash '{{ .Path }}'"
  }
}

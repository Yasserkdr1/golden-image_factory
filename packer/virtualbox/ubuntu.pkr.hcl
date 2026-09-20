packer {

  required_plugins {

    virtualbox = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/virtualbox"
    }

    ansible = {
      version = "~> 1"
      source  = "github.com/hashicorp/ansible"
    }

  }
}


source "virtualbox-iso" "ubuntu" {

  vm_name       = var.vm_name
  guest_os_type = "Ubuntu_64"

  cpus      = 4
  memory    = 8192
  disk_size = 20000

  headless = var.headless

  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  http_directory = "${path.root}/../common/http"

  boot_wait = "5s"
  boot_command = [
    "e<wait><down><down><down><end> autoinstall 'ds=nocloud;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/'<F10>"
  ]


  ssh_username         = var.ssh_username
  ssh_private_key_file = var.ssh_private_key_file
  ssh_timeout          = "30m"

  # The final sealing script shuts down the VM.
  disable_shutdown = true
  shutdown_timeout = "5m"
}


build {

  name = "ubuntu-golden-image"

  sources = [
    "source.virtualbox-iso.ubuntu"
  ]


  # ==========================================================
  # 1. Install Ansible inside the temporary build VM
  # ==========================================================

  provisioner "shell" {

    inline = [
      "apt-get update",
      "DEBIAN_FRONTEND=noninteractive apt-get install -y ansible"
    ]

    execute_command = "echo '${var.ssh_password}' | sudo -S -E bash '{{ .Path }}'"

  }


  # ==========================================================
  # 2. Ansible hardening
  # ==========================================================

  provisioner "ansible-local" {

    playbook_dir = "${path.root}/../../ansible"

    playbook_file = "${path.root}/../../ansible/site.yml"

    inventory_groups = [
      "servers"
    ]

    staging_directory = "/tmp/packer-ansible-hardening"

    clean_staging_directory = true

    extra_arguments = [
      "--extra-vars",
      "ansible_become_password=${var.ssh_password}",

      "--extra-vars",
      "packages_full_upgrade_enabled=true",

      "--extra-vars",
      "grub_password_enabled=true",

      "--extra-vars",
      "grub_password_hash=${var.grub_password_hash}"
    ]

  }


  # ==========================================================
  # 3. Reboot after hardening
  # ==========================================================

  provisioner "shell" {

    inline = [
      "echo '${var.ssh_password}' | sudo -S /usr/sbin/reboot"
    ]

    execute_command   = "{{ .Vars }} bash '{{ .Path }}'"
    expect_disconnect = true

  }


  # ==========================================================
  # 4. Wait until VM is available again
  # ==========================================================

  provisioner "shell" {

    pause_before = "40s"

    inline = [
      "echo 'VM available after reboot'"
    ]

    execute_command = "{{ .Vars }} bash '{{ .Path }}'"

  }


  # ==========================================================
  # 5. Ansible verification
  # ==========================================================

  provisioner "ansible-local" {

    playbook_dir = "${path.root}/../../ansible/tests"

    playbook_file = "${path.root}/../../ansible/tests/verify.yml"

    inventory_groups = [
      "servers"
    ]

    staging_directory = "/tmp/packer-ansible-verify"

    clean_staging_directory = true

    extra_arguments = [
      "--extra-vars",
      "@/tmp/packer-ansible-verify/vars/virtualbox.yml",

      "--extra-vars",
      "ansible_become_password=${var.ssh_password}"
    ]
  }


  # ==========================================================
  # 7. Upload OpenSCAP datastream
  # ==========================================================

  provisioner "file" {

    source = "${path.root}/../../compliance/openscap/ssg-ubuntu2404-ds.xml"

    destination = "/tmp/ssg-ubuntu2404-ds.xml"

  }


  # ==========================================================
  # 8. OpenSCAP validation
  # ==========================================================

  provisioner "shell" {

    script = "${path.root}/../../compliance/openscap/check-compliance.sh"

    execute_command = "echo '${var.ssh_password}' | sudo -S bash '{{ .Path }}'"

  }


  # ==========================================================
  # 9. Lynis validation
  # ==========================================================

  provisioner "shell" {

    script = "${path.root}/../../compliance/lynis/check-score.sh"

    execute_command = "echo '${var.ssh_password}' | sudo -S env MINIMUM_SCORE=88 bash '{{ .Path }}'"

  }


  # ==========================================================
  # 10. Give build user access to validation reports
  # ==========================================================

  provisioner "shell" {

    inline = [
      "echo '${var.ssh_password}' | sudo -S chown -R ${var.ssh_username}:${var.ssh_username} /tmp/golden-image-validation"
    ]

    execute_command = "{{ .Vars }} bash '{{ .Path }}'"

  }


  # ==========================================================
  # 11. Download validation reports to Windows host
  # ==========================================================

  provisioner "file" {

    source = "/tmp/golden-image-validation/"

    destination = "${path.root}/reports/"

    direction = "download"

  }


  # ==========================================================
  # 12. Existing project cleanup
  # ==========================================================

  provisioner "shell" {

    script = "${path.root}/../../scripts/cleanup-image.sh"

    execute_command = "echo '${var.ssh_password}' | sudo -S bash '{{ .Path }}'"

  }


  # ==========================================================
  # 13. Final Golden Image sealing
  #
  # MUST ALWAYS BE THE LAST PROVISIONER
  # ==========================================================

  provisioner "shell" {

    script = "${path.root}/../../scripts/seal-image.sh"

    execute_command = "echo '${var.ssh_password}' | sudo -S bash '{{ .Path }}'"

    expect_disconnect = true
    skip_clean = true

  }

}

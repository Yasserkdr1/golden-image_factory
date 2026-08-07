variable "iso_url" {
  type        = string
  description = "Path or URL to the Ubuntu Server ISO"
}

variable "iso_checksum" {
  type        = string
  description = "Checksum of the Ubuntu Server ISO"
  default     = "none"
}

variable "ssh_username" {
  type        = string
  description = "Temporary account used by Packer"
  default     = "admin"
}

variable "ssh_password" {
  type        = string
  description = "Temporary password used by Packer"
  sensitive   = true
}

variable "vm_name" {
  type        = string
  description = "Name of the VirtualBox VM"
  default     = "ubuntu-24.04-golden-test"
}

variable "headless" {
  type        = bool
  description = "Run VirtualBox without the graphical interface"
  default     = false
}

variable "grub_password_hash" {
  type        = string
  description = "PBKDF2 hash used for GRUB authentication"
  sensitive   = true
  default     = ""
}

variable "ssh_private_key_file" {
  type        = string
  description = "Path to the SSH private key used by Packer"
  sensitive   = true
}

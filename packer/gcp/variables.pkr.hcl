variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "zone" {
  type        = string
  description = "GCP zone used for the temporary build instance"
  default     = "europe-west1-b"
}

variable "machine_type" {
  type        = string
  description = "GCP machine type used during the image build"
  default     = "e2-medium"
}

variable "source_image_family" {
  type        = string
  description = "Ubuntu source image family"
  default     = "ubuntu-2404-lts-amd64"
}

variable "source_image_project_id" {
  type        = string
  description = "Project containing the Ubuntu source image"
  default     = "ubuntu-os-cloud"
}

variable "ssh_username" {
  type        = string
  description = "SSH username used by Packer"
  default     = "packer"
}

variable "image_name" {
  type        = string
  description = "Name of the resulting GCP image"
  default     = "ubuntu-2404-golden"
}

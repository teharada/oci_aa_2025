variable "region" {
  description = "OCI region name, for example ap-tokyo-1"
  type        = string
}

variable "tenancy_ocid" {
  description = "Tenancy OCID used for availability domain lookup"
  type        = string
}

variable "compartment_ocid" {
  description = "Target compartment OCID"
  type        = string
}

variable "ssh_public_key" {
  description = "Optional SSH public key for instance access"
  type        = string
  default     = ""
}

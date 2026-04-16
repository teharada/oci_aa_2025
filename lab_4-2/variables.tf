variable "compartment_ocid" {
  description = "Target compartment OCID"
  type        = string
}

variable "fra_region" {
  description = "FRA region name"
  type        = string
  default     = "eu-frankfurt-1"
}

variable "phx_region" {
  description = "PHX region name"
  type        = string
  default     = "us-phoenix-1"
}

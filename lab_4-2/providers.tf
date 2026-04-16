terraform {
  required_version = ">= 1.5.0"

  required_providers {
    oci = {
      source = "oracle/oci"
    }
  }
}

provider "oci" {
  alias  = "fra"
  region = var.fra_region
}

provider "oci" {
  alias  = "phx"
  region = var.phx_region
}

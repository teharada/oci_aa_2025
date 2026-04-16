locals {
  fra_vcn_cidr = "172.17.0.0/16"
  phx_vcn_cidr = "10.0.0.0/16"

  fra_subnet_cidr = "172.17.0.0/24"
  phx_subnet_cidr = "10.0.0.0/24"

  fra_dns_label = "fra01"
  phx_dns_label = "phx01"
}

resource "oci_core_vcn" "fra_vcn" {
  provider       = oci.fra
  compartment_id = var.compartment_ocid
  display_name   = "FRA-VCN-01"
  cidr_block     = local.fra_vcn_cidr
  dns_label      = local.fra_dns_label
}

resource "oci_core_vcn" "phx_vcn" {
  provider       = oci.phx
  compartment_id = var.compartment_ocid
  display_name   = "PHX-VCN-01"
  cidr_block     = local.phx_vcn_cidr
  dns_label      = local.phx_dns_label
}

resource "oci_core_internet_gateway" "fra_igw" {
  provider       = oci.fra
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.fra_vcn.id
  display_name   = "FRA-IGW"
  enabled        = true
}

resource "oci_core_internet_gateway" "phx_igw" {
  provider       = oci.phx
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.phx_vcn.id
  display_name   = "PHX-IGW"
  enabled        = true
}

resource "oci_core_drg" "fra_drg" {
  provider       = oci.fra
  compartment_id = var.compartment_ocid
  display_name   = "FRA-DRG"
}

resource "oci_core_drg" "phx_drg" {
  provider       = oci.phx
  compartment_id = var.compartment_ocid
  display_name   = "PHX-DRG"
}

resource "oci_core_remote_peering_connection" "phx_rpc" {
  provider       = oci.phx
  compartment_id = var.compartment_ocid
  drg_id         = oci_core_drg.phx_drg.id
  display_name   = "PHX-RPC"
}

resource "oci_core_remote_peering_connection" "fra_rpc" {
  provider         = oci.fra
  compartment_id   = var.compartment_ocid
  drg_id           = oci_core_drg.fra_drg.id
  display_name     = "FRA-RPC"
  peer_id          = oci_core_remote_peering_connection.phx_rpc.id
  peer_region_name = var.phx_region
}

resource "oci_core_default_security_list" "fra_default_sl" {
  provider                   = oci.fra
  manage_default_resource_id  = oci_core_vcn.fra_vcn.default_security_list_id
  display_name               = "Default Security List - FRA-VCN-01"

  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"

    tcp_options {
      min = 22
      max = 22
    }
  }

  ingress_security_rules {
    protocol    = "1"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"

    icmp_options {
      type = 3
      code = 4
    }
  }

  ingress_security_rules {
    protocol    = "1"
    source      = local.fra_vcn_cidr
    source_type = "CIDR_BLOCK"

    icmp_options {
      type = 3
      code = -1
    }
  }

  ingress_security_rules {
    protocol    = "1"
    source      = local.phx_vcn_cidr
    source_type = "CIDR_BLOCK"

    icmp_options {
      type = 8
      code = 0
    }
  }

  egress_security_rules {
    protocol         = "all"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
  }
}

resource "oci_core_default_security_list" "phx_default_sl" {
  provider                   = oci.phx
  manage_default_resource_id  = oci_core_vcn.phx_vcn.default_security_list_id
  display_name               = "Default Security List - PHX-VCN-01"

  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"

    tcp_options {
      min = 22
      max = 22
    }
  }

  ingress_security_rules {
    protocol    = "1"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"

    icmp_options {
      type = 3
      code = 4
    }
  }

  ingress_security_rules {
    protocol    = "1"
    source      = local.phx_vcn_cidr
    source_type = "CIDR_BLOCK"

    icmp_options {
      type = 3
      code = -1
    }
  }

  ingress_security_rules {
    protocol    = "1"
    source      = local.fra_vcn_cidr
    source_type = "CIDR_BLOCK"

    icmp_options {
      type = 8
      code = 0
    }
  }

  egress_security_rules {
    protocol         = "all"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
  }
}

resource "oci_core_default_route_table" "fra_default_rt" {
  provider                  = oci.fra
  manage_default_resource_id = oci_core_vcn.fra_vcn.default_route_table_id
  display_name              = "Default Route Table - FRA-VCN-01"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.fra_igw.id
  }

  route_rules {
    destination       = local.phx_vcn_cidr
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_drg.fra_drg.id
  }
}

resource "oci_core_default_route_table" "phx_default_rt" {
  provider                  = oci.phx
  manage_default_resource_id = oci_core_vcn.phx_vcn.default_route_table_id
  display_name              = "Default Route Table - PHX-VCN-01"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.phx_igw.id
  }

  route_rules {
    destination       = local.fra_vcn_cidr
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_drg.phx_drg.id
  }
}

resource "oci_core_subnet" "fra_pub1" {
  provider                   = oci.fra
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.fra_vcn.id
  display_name               = "pub1"
  cidr_block                 = local.fra_subnet_cidr
  dns_label                  = "pub1"
  prohibit_public_ip_on_vnic  = false
  security_list_ids          = [oci_core_default_security_list.fra_default_sl.id]
}

resource "oci_core_subnet" "phx_pub1" {
  provider                   = oci.phx
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.phx_vcn.id
  display_name               = "pub1"
  cidr_block                 = local.phx_subnet_cidr
  dns_label                  = "pub1"
  prohibit_public_ip_on_vnic  = false
  security_list_ids          = [oci_core_default_security_list.phx_default_sl.id]
}

resource "oci_core_drg_attachment" "fra_vcn_attachment" {
  provider         = oci.fra
  drg_id           = oci_core_drg.fra_drg.id
  display_name     = "FRA-VCN-ATTACHMENT"

  network_details {
    id            = oci_core_vcn.fra_vcn.id
    type          = "VCN"
    vcn_route_type = "VCN_CIDRS"
  }
}

resource "oci_core_drg_attachment" "phx_vcn_attachment" {
  provider         = oci.phx
  drg_id           = oci_core_drg.phx_drg.id
  display_name     = "PHX-VCN-ATTACHMENT"

  network_details {
    id            = oci_core_vcn.phx_vcn.id
    type          = "VCN"
    vcn_route_type = "VCN_CIDRS"
  }
}

locals {
  vcn1_cidr = "172.16.0.0/16"
  vcn2_cidr = "192.168.0.0/16"
  pub1_cidr = "172.16.0.0/24"
  pub2_cidr = "192.168.0.0/24"
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_images" "oracle_linux_a1" {
  compartment_id    = var.compartment_ocid
  operating_system   = "Oracle Linux"
  shape             = "VM.Standard.A1.Flex"
  sort_by           = "TIMECREATED"
  sort_order        = "DESC"
}

resource "oci_core_vcn" "vcn1" {
  compartment_id = var.compartment_ocid
  display_name   = "VCN-01"
  cidr_block     = local.vcn1_cidr
  dns_label      = "vcn01"
}

resource "oci_core_vcn" "vcn2" {
  compartment_id = var.compartment_ocid
  display_name   = "VCN-02"
  cidr_block     = local.vcn2_cidr
  dns_label      = "vcn02"
}

resource "oci_core_internet_gateway" "vcn1_igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn1.id
  display_name   = "IGW-01"
  enabled        = true
}

resource "oci_core_internet_gateway" "vcn2_igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn2.id
  display_name   = "IGW-02"
  enabled        = true
}

resource "oci_core_local_peering_gateway" "vcn1_lpg" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn1.id
  display_name    = "LPG-01"
}

resource "oci_core_local_peering_gateway" "vcn2_lpg" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn2.id
  display_name    = "LPG-02"
  peer_id         = oci_core_local_peering_gateway.vcn1_lpg.id
}

resource "oci_core_route_table" "vcn1_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn1.id
  display_name    = "RT-01"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.vcn1_igw.id
  }

  route_rules {
    destination       = local.vcn2_cidr
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_local_peering_gateway.vcn1_lpg.id
  }
}

resource "oci_core_route_table" "vcn2_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn2.id
  display_name    = "RT-02"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.vcn2_igw.id
  }

  route_rules {
    destination       = local.vcn1_cidr
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_local_peering_gateway.vcn2_lpg.id
  }
}

resource "oci_core_default_security_list" "vcn1_default_sl" {
  manage_default_resource_id = oci_core_vcn.vcn1.default_security_list_id
  display_name               = "Default Security List - VCN-01"

  # Default rule 1: SSH ingress
  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"

    tcp_options {
      min = 22
      max = 22
    }
  }

  # Default rule 2: PMTU discovery
  ingress_security_rules {
    protocol    = "1"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"

    icmp_options {
      type = 3
      code = 4
    }
  }

  # Default rule 3: VCN internal ICMP errors
  ingress_security_rules {
    protocol    = "1"
    source      = local.vcn1_cidr
    source_type = "CIDR_BLOCK"

    icmp_options {
      type = 3
      code = -1
    }
  }

  # Added rule: allow ping from VCN-02
  ingress_security_rules {
    protocol    = "1"
    source      = local.vcn2_cidr
    source_type = "CIDR_BLOCK"

    icmp_options {
      type = 8
      code = 0
    }
  }

  # Default rule: all egress
  egress_security_rules {
    protocol       = "all"
    destination    = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
  }
}

resource "oci_core_default_security_list" "vcn2_default_sl" {
  manage_default_resource_id = oci_core_vcn.vcn2.default_security_list_id
  display_name               = "Default Security List - VCN-02"

  # Default rule 1: SSH ingress
  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"

    tcp_options {
      min = 22
      max = 22
    }
  }

  # Default rule 2: PMTU discovery
  ingress_security_rules {
    protocol    = "1"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"

    icmp_options {
      type = 3
      code = 4
    }
  }

  # Default rule 3: VCN internal ICMP errors
  ingress_security_rules {
    protocol    = "1"
    source      = local.vcn2_cidr
    source_type = "CIDR_BLOCK"

    icmp_options {
      type = 3
      code = -1
    }
  }

  # Added rule: allow ping from VCN-01
  ingress_security_rules {
    protocol    = "1"
    source      = local.vcn1_cidr
    source_type = "CIDR_BLOCK"

    icmp_options {
      type = 8
      code = 0
    }
  }

  # Default rule: all egress
  egress_security_rules {
    protocol       = "all"
    destination    = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
  }
}

resource "oci_core_subnet" "pub1" {
  compartment_id            = var.compartment_ocid
  vcn_id                    = oci_core_vcn.vcn1.id
  display_name              = "pub1"
  cidr_block                = local.pub1_cidr
  dns_label                 = "pub1"
  prohibit_public_ip_on_vnic = false
  route_table_id            = oci_core_route_table.vcn1_rt.id
  security_list_ids         = [oci_core_default_security_list.vcn1_default_sl.id]
}

resource "oci_core_subnet" "pub2" {
  compartment_id            = var.compartment_ocid
  vcn_id                    = oci_core_vcn.vcn2.id
  display_name              = "pub2"
  cidr_block                = local.pub2_cidr
  dns_label                 = "pub2"
  prohibit_public_ip_on_vnic = false
  route_table_id            = oci_core_route_table.vcn2_rt.id
  security_list_ids         = [oci_core_default_security_list.vcn2_default_sl.id]
}

resource "oci_core_instance" "vm1" {
  compartment_id      = var.compartment_ocid
  availability_domain  = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "VM1"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 1
    memory_in_gbs = 6
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.pub1.id
    assign_public_ip = true
    hostname_label   = "vm1"
    display_name     = "VM1-VNIC"
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.oracle_linux_a1.images[0].id
  }

  metadata = var.ssh_public_key == "" ? {} : {
    ssh_authorized_keys = var.ssh_public_key
  }
}

resource "oci_core_instance" "vm2" {
  compartment_id      = var.compartment_ocid
  availability_domain  = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "VM2"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 1
    memory_in_gbs = 6
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.pub2.id
    assign_public_ip = true
    hostname_label   = "vm2"
    display_name     = "VM2-VNIC"
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.oracle_linux_a1.images[0].id
  }

  metadata = var.ssh_public_key == "" ? {} : {
    ssh_authorized_keys = var.ssh_public_key
  }
}

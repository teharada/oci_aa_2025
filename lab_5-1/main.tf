locals {
  vcn_cidr         = "172.17.0.0/16"
  public_subnet_cidr  = "172.17.0.0/24"
  private_subnet_cidr = "172.17.1.0/24"

  public_dns_label  = "sub1"
  private_dns_label = "sub2"

  lb_backend_port   = 80
  lb_listener_port  = 80
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_images" "oracle_linux_a1" {
  compartment_id      = var.compartment_ocid
  operating_system    = "Oracle Linux"
  operating_system_version = "8"
  shape               = "VM.Standard.A1.Flex"
  sort_by             = "TIMECREATED"
  sort_order          = "DESC"
}

resource "oci_core_vcn" "vcn01" {
  compartment_id = var.compartment_ocid
  display_name   = "VCN-01"
  cidr_block     = local.vcn_cidr
  dns_label      = "vcn01"
}

resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn01.id
  display_name   = "IGW-01"
  enabled        = true
}

resource "oci_core_nat_gateway" "natgw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn01.id
  display_name   = "NATGW-01"
}

resource "oci_core_default_route_table" "default_rt" {
  manage_default_resource_id = oci_core_vcn.vcn01.default_route_table_id
  display_name               = "Default Route Table - VCN-01"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

resource "oci_core_route_table" "private_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn01.id
  display_name   = "PRIVATE-RT-01"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.natgw.id
  }
}

resource "oci_core_default_security_list" "default_sl" {
  manage_default_resource_id = oci_core_vcn.vcn01.default_security_list_id
  display_name               = "Default Security List - VCN-01"

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
    source      = local.vcn_cidr
    source_type = "CIDR_BLOCK"

    icmp_options {
      type = 3
      code = -1
    }
  }

  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"

    tcp_options {
      min = 80
      max = 80
    }
  }

  egress_security_rules {
    protocol         = "all"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
  }
}

resource "oci_core_security_list" "private_sl" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.vcn01.id
  display_name   = "PRIVATE-SL-01"

  ingress_security_rules {
    protocol    = "6"
    source      = local.vcn_cidr
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
    source      = local.vcn_cidr
    source_type = "CIDR_BLOCK"

    icmp_options {
      type = 3
      code = -1
    }
  }

  ingress_security_rules {
    protocol    = "6"
    source      = local.public_subnet_cidr
    source_type = "CIDR_BLOCK"

    tcp_options {
      min = 80
      max = 80
    }
  }

  egress_security_rules {
    protocol         = "all"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
  }
}

resource "oci_core_subnet" "sub1" {
  compartment_id            = var.compartment_ocid
  vcn_id                    = oci_core_vcn.vcn01.id
  display_name              = "sub1"
  cidr_block                = local.public_subnet_cidr
  dns_label                 = local.public_dns_label
  prohibit_public_ip_on_vnic = false
  security_list_ids         = [oci_core_default_security_list.default_sl.id]
}

resource "oci_core_subnet" "sub2" {
  compartment_id            = var.compartment_ocid
  vcn_id                    = oci_core_vcn.vcn01.id
  display_name              = "sub2"
  cidr_block                = local.private_subnet_cidr
  dns_label                 = local.private_dns_label
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.private_rt.id
  security_list_ids         = [oci_core_security_list.private_sl.id]
}

resource "oci_core_instance" "vm1" {
  compartment_id     = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name       = "VM-01"
  shape              = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 1
    memory_in_gbs  = 6
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.sub2.id
    assign_public_ip = false
    hostname_label   = "vm01"
    display_name     = "VM-01-VNIC"
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.oracle_linux_a1.images[0].id
  }

  metadata = merge(
    var.ssh_public_key == "" ? {} : { ssh_authorized_keys = var.ssh_public_key },
    {
      user_data = base64encode(templatefile("${path.module}/cloud-init.sh.tftpl", {
        hostname = "VM-01"
      }))
    }
  )
}

resource "oci_core_instance" "vm2" {
  compartment_id      = var.compartment_ocid
  availability_domain  = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "VM-02"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 1
    memory_in_gbs  = 6
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.sub2.id
    assign_public_ip = false
    hostname_label   = "vm02"
    display_name     = "VM-02-VNIC"
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.oracle_linux_a1.images[0].id
  }

  metadata = merge(
    var.ssh_public_key == "" ? {} : { ssh_authorized_keys = var.ssh_public_key },
    {
      user_data = base64encode(templatefile("${path.module}/cloud-init.sh.tftpl", {
        hostname = "VM-02"
      }))
    }
  )
}

data "oci_core_vnic_attachments" "vm1_attachments" {
  compartment_id = var.compartment_ocid
  instance_id    = oci_core_instance.vm1.id
}

data "oci_core_vnic" "vm1_vnic" {
  vnic_id = data.oci_core_vnic_attachments.vm1_attachments.vnic_attachments[0].vnic_id
}

data "oci_core_vnic_attachments" "vm2_attachments" {
  compartment_id = var.compartment_ocid
  instance_id    = oci_core_instance.vm2.id
}

data "oci_core_vnic" "vm2_vnic" {
  vnic_id = data.oci_core_vnic_attachments.vm2_attachments.vnic_attachments[0].vnic_id
}

resource "oci_load_balancer_load_balancer" "lb01" {
  compartment_id = var.compartment_ocid
  display_name   = "LB-01"
  shape          = "flexible"
  subnet_ids     = [oci_core_subnet.sub1.id]

  shape_details {
    minimum_bandwidth_in_mbps = 10
    maximum_bandwidth_in_mbps = 10
  }
}

resource "oci_load_balancer_backend_set" "lb01_bs" {
  name             = "LB-01-BS"
  load_balancer_id = oci_load_balancer_load_balancer.lb01.id
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol         = "HTTP"
    port             = local.lb_backend_port
    url_path         = "/"
    return_code      = 200
    interval_ms      = 10000
    timeout_in_millis = 3000
  }
}

resource "oci_load_balancer_backend" "vm1_backend" {
  load_balancer_id = oci_load_balancer_load_balancer.lb01.id
  backendset_name  = oci_load_balancer_backend_set.lb01_bs.name
  ip_address       = data.oci_core_vnic.vm1_vnic.private_ip_address
  port             = local.lb_backend_port
  backup           = false
  drain            = false
  offline          = false
  weight           = 1
}

resource "oci_load_balancer_backend" "vm2_backend" {
  load_balancer_id = oci_load_balancer_load_balancer.lb01.id
  backendset_name  = oci_load_balancer_backend_set.lb01_bs.name
  ip_address       = data.oci_core_vnic.vm2_vnic.private_ip_address
  port             = local.lb_backend_port
  backup           = false
  drain            = false
  offline          = false
  weight           = 1
}

resource "oci_load_balancer_listener" "lb01_listener" {
  load_balancer_id         = oci_load_balancer_load_balancer.lb01.id
  name                     = "LB-01-HTTP"
  default_backend_set_name = oci_load_balancer_backend_set.lb01_bs.name
  port                     = local.lb_listener_port
  protocol                 = "HTTP"
}

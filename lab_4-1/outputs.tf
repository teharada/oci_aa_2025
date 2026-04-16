output "vcn1_id" {
  value = oci_core_vcn.vcn1.id
}

output "vcn2_id" {
  value = oci_core_vcn.vcn2.id
}

output "vm1_id" {
  value = oci_core_instance.vm1.id
}

output "vm2_id" {
  value = oci_core_instance.vm2.id
}

output "vcn1_lpg_id" {
  value = oci_core_local_peering_gateway.vcn1_lpg.id
}

output "vcn2_lpg_id" {
  value = oci_core_local_peering_gateway.vcn2_lpg.id
}

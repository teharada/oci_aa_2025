output "vcn_id" {
  value = oci_core_vcn.vcn01.id
}

output "subnet_public_id" {
  value = oci_core_subnet.sub1.id
}

output "subnet_private_id" {
  value = oci_core_subnet.sub2.id
}

output "vm1_id" {
  value = oci_core_instance.vm1.id
}

output "vm2_id" {
  value = oci_core_instance.vm2.id
}

output "vm1_private_ip" {
  value = data.oci_core_vnic.vm1_vnic.private_ip_address
}

output "vm2_private_ip" {
  value = data.oci_core_vnic.vm2_vnic.private_ip_address
}

output "lb01_id" {
  value = oci_load_balancer_load_balancer.lb01.id
}

output "lb_public_ip" {
  value = oci_load_balancer_load_balancer.lb01.ip_address_details[0].ip_address
}

output "lb_url" {
  value = "http://${oci_load_balancer_load_balancer.lb01.ip_address_details[0].ip_address}"
}
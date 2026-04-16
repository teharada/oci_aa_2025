output "fra_vcn_id" {
  value = oci_core_vcn.fra_vcn.id
}

output "phx_vcn_id" {
  value = oci_core_vcn.phx_vcn.id
}

output "fra_drg_id" {
  value = oci_core_drg.fra_drg.id
}

output "phx_drg_id" {
  value = oci_core_drg.phx_drg.id
}

output "fra_rpc_id" {
  value = oci_core_remote_peering_connection.fra_rpc.id
}

output "phx_rpc_id" {
  value = oci_core_remote_peering_connection.phx_rpc.id
}

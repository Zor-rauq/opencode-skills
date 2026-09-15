output "id" {
  description = "Identifiant de la VM cote IaaS."
  value       = openstack_compute_instance_v2.this.id
}

output "ip" {
  description = "IP effectivement attribuee au port."
  value       = openstack_networking_port_v2.this.all_fixed_ips[0]
}

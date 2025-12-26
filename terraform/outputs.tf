# Network outputs
output "dmz_network_id" {
  value = openstack_networking_network_v2.dmz_net.id
}

output "private_network_id" {
  value = openstack_networking_network_v2.private_net.id
}

output "dmz_subnet_id" {
  value = openstack_networking_subnet_v2.dmz_subnet.id
}

output "private_subnet_id" {
  value = openstack_networking_subnet_v2.private_subnet.id
}

output "dmz_subnet_cidr" {
  value = openstack_networking_subnet_v2.dmz_subnet.cidr
}

output "private_subnet_cidr" {
  value = openstack_networking_subnet_v2.private_subnet.cidr
}

# Router outputs
output "router_id" {
  value = openstack_networking_router_v2.router.id
}

output "router_dmz_interface_id" {
  value = openstack_networking_router_interface_v2.router_dmz_if.id
}

# Instance outputs
output "gateway_floating_ip" {
  value = openstack_networking_floatingip_v2.gateway_fip.address
}

output "gateway_private_ip" {
  value = openstack_networking_port_v2.gateway_private_port.all_fixed_ips[0]
}

output "edge_private_ips" {
  value = [for p in openstack_networking_port_v2.edge_ports : p.all_fixed_ips[0]]
}

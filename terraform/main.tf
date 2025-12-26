# Public network
data "openstack_networking_network_v2" "public" {
  name = var.public_network_name
}

# Networks
resource "openstack_networking_network_v2" "dmz_net" {
  name           = "a-dmz-net"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "dmz_subnet" {
  name            = "a-dmz-subnet"
  network_id      = openstack_networking_network_v2.dmz_net.id
  cidr            = var.dmz_cidr
  ip_version      = 4
  dns_nameservers = var.dns_nameservers
}

resource "openstack_networking_network_v2" "private_net" {
  name           = "a-private-net"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "private_subnet" {
  name            = "a-private-subnet"
  network_id      = openstack_networking_network_v2.private_net.id
  cidr            = var.private_cidr
  ip_version      = 4
  dns_nameservers = var.dns_nameservers
  no_gateway      = true
}

# Router: public <-> dmz-subnet
resource "openstack_networking_router_v2" "router" {
  name                = "tenantA-router"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.public.id
  enable_snat         = true
}

resource "openstack_networking_router_interface_v2" "router_dmz_if" {
  router_id = openstack_networking_router_v2.router.id
  subnet_id = openstack_networking_subnet_v2.dmz_subnet.id
}

# Security Groups
resource "openstack_networking_secgroup_v2" "gateway_sg" {
  name        = "sg-gateway"
  description = "Gateway: SSH + LB port from internet; registry from private; allow to reach edges"
}

resource "openstack_networking_secgroup_rule_v2" "gw_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.admin_cidr
  security_group_id = openstack_networking_secgroup_v2.gateway_sg.id
}

resource "openstack_networking_secgroup_rule_v2" "gw_lb" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = var.lb_port
  port_range_max    = var.lb_port
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.gateway_sg.id
}

resource "openstack_networking_secgroup_rule_v2" "gw_registry_from_private" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = var.registry_port
  port_range_max    = var.registry_port
  remote_ip_prefix  = var.private_cidr
  security_group_id = openstack_networking_secgroup_v2.gateway_sg.id
}

resource "openstack_networking_secgroup_rule_v2" "gw_port_for_hap" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 3142
  port_range_max    = 3142
  remote_ip_prefix  = var.private_cidr
  security_group_id = openstack_networking_secgroup_v2.gateway_sg.id
}

resource "openstack_networking_secgroup_rule_v2" "gw_for_http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = var.private_cidr
  security_group_id = openstack_networking_secgroup_v2.gateway_sg.id
}

resource "openstack_networking_secgroup_v2" "edge_sg" {
  name        = "sg-edge"
  description = "Edges: only accept SSH + app from gateway"
}

# Allow SSH to edges only from instances in gateway SG
resource "openstack_networking_secgroup_rule_v2" "edge_ssh_from_gateway" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_group_id   = openstack_networking_secgroup_v2.gateway_sg.id
  security_group_id = openstack_networking_secgroup_v2.edge_sg.id
}

# Allow app port on edges only from gateway SG
resource "openstack_networking_secgroup_rule_v2" "edge_app_from_gateway" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = var.edge_app_port
  port_range_max    = var.edge_app_port
  remote_group_id   = openstack_networking_secgroup_v2.gateway_sg.id
  security_group_id = openstack_networking_secgroup_v2.edge_sg.id
}

# Images/Flavors
data "openstack_images_image_v2" "ubuntu" {
  name        = var.image_name
  most_recent = true
}

data "openstack_compute_flavor_v2" "gateway_flavor" {
  name = var.gateway_flavor_name
}

data "openstack_compute_flavor_v2" "edge_flavor" {
  name = var.edge_flavor_name
}

# Ports (gateway has 2 NICs)
resource "openstack_networking_port_v2" "gateway_dmz_port" {
  name           = "gateway-dmz-port"
  network_id     = openstack_networking_network_v2.dmz_net.id
  admin_state_up = true

  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.dmz_subnet.id
  }

  security_group_ids = [
    openstack_networking_secgroup_v2.gateway_sg.id
  ]

  # QUAN TRỌNG: Đợi router interface sẵn sàng trước khi tạo port
  depends_on = [
    openstack_networking_router_interface_v2.router_dmz_if
  ]
}

resource "openstack_networking_port_v2" "gateway_private_port" {
  name           = "gateway-private-port"
  network_id     = openstack_networking_network_v2.private_net.id
  admin_state_up = true

  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.private_subnet.id
  }

  security_group_ids = [
    openstack_networking_secgroup_v2.gateway_sg.id
  ]
}

# Edge ports
resource "openstack_networking_port_v2" "edge_ports" {
  count          = 2
  name           = "edge-${count.index + 1}-port"
  network_id     = openstack_networking_network_v2.private_net.id
  admin_state_up = true

  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.private_subnet.id
  }

  security_group_ids = [
    openstack_networking_secgroup_v2.edge_sg.id
  ]
}

# Instances
resource "openstack_compute_instance_v2" "gateway" {
  name            = "gateway"
  image_id        = data.openstack_images_image_v2.ubuntu.id
  flavor_id       = data.openstack_compute_flavor_v2.gateway_flavor.id  
  key_pair        = var.keypair
  security_groups = [] # using port-level SGs
  user_data = local.gateway_user_data

  network {
    port = openstack_networking_port_v2.gateway_dmz_port.id
  }
  network {
    port = openstack_networking_port_v2.gateway_private_port.id
  }

  depends_on = [
    openstack_networking_router_interface_v2.router_dmz_if,
    openstack_networking_port_v2.gateway_dmz_port,
    openstack_networking_port_v2.gateway_private_port
  ]

  timeouts {
    create = "15m"
    update = "10m"
    delete = "10m"
  }

  stop_before_destroy = true
}


resource "openstack_compute_instance_v2" "edges" {
  count           = var.edge_count
  name            = "edge-host-${count.index + 1}"
  image_id        = data.openstack_images_image_v2.ubuntu.id
  flavor_id       = data.openstack_compute_flavor_v2.edge_flavor.id 
  key_pair        = var.keypair
  security_groups = []

  network {
    port = openstack_networking_port_v2.edge_ports[count.index].id
  }

  # Đảm bảo ports đã sẵn sàng
  depends_on = [
    openstack_networking_port_v2.edge_ports
  ]

  # Thêm timeouts
  timeouts {
    create = "15m"
    update = "10m"
    delete = "10m"
  }

  stop_before_destroy = true
}

# Floating IP for gateway (on DMZ port)
resource "openstack_networking_floatingip_v2" "gateway_fip" {
  pool = var.public_network_name
}

resource "openstack_networking_floatingip_associate_v2" "gateway_fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.gateway_fip.address
  port_id     = openstack_networking_port_v2.gateway_dmz_port.id

  depends_on = [
    openstack_networking_router_v2.router,
    openstack_networking_router_interface_v2.router_dmz_if
  ]
}

# Generate Ansible inventory after apply
locals {
  gateway_fip        = openstack_networking_floatingip_v2.gateway_fip.address
  gateway_private_ip = openstack_networking_port_v2.gateway_private_port.all_fixed_ips[0]
  edge_ips           = [for p in openstack_networking_port_v2.edge_ports : p.all_fixed_ips[0]]
}

locals {
  gateway_user_data = <<-EOF
  #cloud-config
  write_files:
    - path: /etc/netplan/99-gateway.yaml
      permissions: '0644'
      content: |
        network:
          version: 2
          renderer: networkd
          ethernets:
            dmz0:
              match:
                macaddress: "${lower(openstack_networking_port_v2.gateway_dmz_port.mac_address)}"
              set-name: dmz0
              dhcp4: true
              dhcp4-overrides:
                route-metric: 50

            priv0:
              match:
                macaddress: "${lower(openstack_networking_port_v2.gateway_private_port.mac_address)}"
              set-name: priv0
              dhcp4: true
              dhcp4-overrides:
                use-routes: false
                route-metric: 200

  runcmd:
    - [ bash, -lc, "netplan generate && netplan apply" ]
    # Safety: nếu vẫn còn default lạc sang priv0 thì xoá ngay
    - [ bash, -lc, "ip route | grep -q 'default.*dev priv0' && ip route del default dev priv0 || true" ]
    - [ bash, -lc, "echo '=== DEFAULT ROUTES ===' && ip route | grep ^default || true" ]
  EOF
}


resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/inventory.ini"
  content  = <<-EOF
[gateway]
gateway ansible_host=${local.gateway_fip} ansible_user=ubuntu


[gateway:vars]
ansible_ssh_common_args=-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null

[edges]
edge1 ansible_host=${local.edge_ips[0]} ansible_user=ubuntu
edge2 ansible_host=${local.edge_ips[1]} ansible_user=ubuntu

[edges:vars]
ansible_ssh_common_args=-o ProxyJump=ubuntu@${local.gateway_fip} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null

[all:vars]
# SSH key on ADMIN machine:
ansible_ssh_private_key_file=/home/deployer/.ssh/id_ecdsa

# Ports/settings
lb_port=${var.lb_port}
edge_app_port=${var.edge_app_port}
registry_port=${var.registry_port}

gateway_private_ip=${local.gateway_private_ip}
EOF

  depends_on = [openstack_networking_floatingip_associate_v2.gateway_fip_assoc]
}

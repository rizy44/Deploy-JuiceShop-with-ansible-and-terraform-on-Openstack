variable "os_user_domain_name" { default = "Default" }

variable "public_network_name" { default = "public1" }

variable "dmz_cidr"     { default = "10.10.10.0/24" }
variable "private_cidr" { default = "10.10.20.0/24" }

variable "image_name"  { default = "ubuntu-22.04" }
variable "gateway_flavor_name" { default = "m1.small" }
variable "edge_flavor_name"    { default = "m2.nano"  }
variable "keypair"     {}

variable "edge_count" { default = 2 }

variable "dns_nameservers" {
  type    = list(string)
  default = ["1.1.1.1", "8.8.8.8"]
}

# Ports
variable "lb_port"       { default = 9090 }
variable "edge_app_port" { default = 8080 }
variable "registry_port" { default = 5000 }

# SSH
variable "admin_cidr" {
  description = "CIDR allowed to SSH into gateway (set to your public IP/32 for safety)."
  default     = "0.0.0.0/0"
}

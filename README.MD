#  Deploy OWASP Juice Shop on OpenStack using Terraform and Ansible

This project demonstrates an **end-to-end deployment pipeline** for running **OWASP Juice Shop** on **OpenStack** 
- **Terraform** – provision OpenStack infrastructure  
- **Ansible** – configure gateway, edges, registry, proxy, and app runtime  
- **Kolla-Ansible** – deploy and manage OpenStack services  
- **HAProxy** – load balancing traffic from gateway to edge nodes  

The architecture follows a **Gateway → Edge** model with a **private Docker registry** and **APT proxy**.
---

## Repository Structure

```text
.
├── README.md                  # This file: docs and usage
├── ansible/
│   ├── site.yml               # Main playbook entry (or include)
│   └── playbooks/
│       ├── gateway.yml        # Gateway: registry, apt proxy, HAProxy
│       ├── edges.yml          # Edge nodes: pull image, run Juice Shop
│       ├── edges_2.yml        # (Advance) Alternate/extra edge orchestration
│       ├── gateway_repo.yml   # (Advance) Private APT repository
│       └── templates/
│           └── haproxy.cfg.j2 # HAProxy template
├── terraform/
│   ├── main.tf                # Terraform configuration
│   ├── outputs.tf             
│   ├── provider.tf
│   ├── variables.tf           # Modify variables
│   └── json/                  # Supporting JSON files
```
## Architecture Overview
```
Laptop / Browser
        |
        v
+--------------------+
| Gateway (Public)   |
| - HAProxy (LB)     |
| - Docker Registry  |
| - apt-cacher-ng    |
+--------------------+
        |
        v
+--------------------+
| Edge Nodes (Private)|
| - Docker           |
| - Juice Shop       |
+--------------------+
```
## How to run
### Terraform
```
cd terraform
terraform init	
terraform plan 
terraform apply -auto-approve
terraform destroy -auto-approve
#Optional, remove cache
rm -rf .terraform .terraform.lock.hcl
```

After run, terraform will generate inventory,ini for ansible to run task.

###  Inventory Validation & Debugging
```bash
ansible-inventory -i /etc/kolla/ansible/inventory/tenantA-inventory --list
ansible -i /etc/kolla/ansible/inventory/tenantA-inventory -m ping all
```

### Monitoring
```
# 1. application logs
docker logs [id]
# 2. OS logs
# all
ls /var/log
sudo journalctl
#OCI-based applications
sudo journalctl -u docker
# 3. Network logs
# Kernel network events
dmesg
dmesg | grep -i net
dmesg -T | grep -Ei 'net|tcp|udp|eth'
# System journal (network services)
sudo journalctl
sudo journalctl | grep -Ei 'network|tcp|udp|eth|docker'
# 4. Mornitoting
sudo tcpdump -i any
sudo tcpdump -i any port 8080 -w juice.pcap
docker logs -f condescending_solomon > app.log
sudo journalctl -u docker > docker.log
```

### Note
```
#Notes for usage later: 
ssh -i ~/.ssh/id_ecdsa ubuntu@<floating-ip>
```


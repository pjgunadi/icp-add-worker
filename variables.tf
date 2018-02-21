variable vsphere_user {
    description = "vCenter user"
}
variable vsphere_password {
    description = "vCenter password"
}
variable vsphere_server {
    description = "vCenter server"
}
variable datacenter {
    description = "vCenter Datacenter"
}
variable datastore {
    description = "vCenter Datastore"
    type = "list"
    default = ["v3700_vol3_datastore", "v3700_vol4_datastore", "v3700_vol5_datastore"]
}
variable resource_pool {
    description = "vCenter Cluster/Resource pool"
}
variable network {
    description = "vCenter Network"
    default = "VM Network"
}
variable osfamily {
    description = "Operating System"
    default = "ubuntu"
}
variable template {
    description = "VM Template"
    type = "map"
    default = {
        "redhat"="rhel74_base"
        "ubuntu"="ubuntu1604_base"
    }
}
variable ssh_user {
    description = "VM Username"
}
variable ssh_password {
    description = "VM Password"
}
variable vm_domain {
    description = "VM Domain"
}
variable timezone {
    description = "Time Zone"
    default = "Asia/Singapore"
}
variable dns_list {
    description = "DNS List"
    type = "list"
}
variable "instance_prefix" {
    default = "icp"
}
variable "vm_private_key_file" {
    default = ""
}
variable "vm_public_key_file" {
    default = "vmware_key.pub"
}
variable "bastion_host" {
    default = ""
}
variable "bastion_user" {
    default = ""
}
variable "bastion_private_key" {
    default = ""
}
##### ICP Instance details ######
variable "icp_version" {
    description = "ICP Version"
    default = "2.1.0.1"
}
variable icp_boot_node_ip {
    default = ""
}
variable icp_source_server {
    default = ""
}
variable icp_source_user {
    default = ""
}
variable icp_source_password {
    default = ""
}
variable icp_source_path {
    default = ""
}
variable icp_install_path {
    default = "/opt/ibm/cluster"
}
variable icp_private_key_file {
    default = "/opt/ibm/cluster/ssh_key"
}
variable icp_public_key_file {
    default = "icp_key.pub"
}
variable "icpadmin_password" {
    description = "ICP admin password"
    default = "admin"
}
variable "existing_workers" {
    default = []
}
variable "worker" {
  type = "map"
  default = {
    nodes       = "3"
    name        = "worker"
    cpu_cores   = "8"
    kubelet_lv  = "10"
    docker_lv   = "70"
    memory      = "8192"
    ipaddresses = "192.168.1.90,192.168.1.91,192.168.1.92"
    netmask     = "24"
    gateway     = "192.168.1.1"    
  }
}
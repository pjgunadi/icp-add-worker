# Terraform Template for Adding ICP Worker Node in VMware

## Use Case
- IBM Cloud Private (ICP) has already been installed in a VMware Cluster
- Requires to add or remove Worker node of ICP Cluster

## Summary
This terraform template perform the following tasks:
- Provision / Remove Worker VMs in VMWare Cluster
- Connect to ICP Boot node to install new worker node or uninstall existing worker node

### Prerequsite - vSphere Preparation
Before deploying ICP in your vSphere Cluster environment, verify the following checklist:
1. Ensure you have a valid username and password to access vCenter
2. For ICP Enterprise edition, download the ICP installer from IBM Passport Advantage and save it in a local SFTP Server
3. Internet connection to download ICP (Community Edition) and OS package dependencies
4. It is assumed that there is existing Linux VM template from existing ICP environment. Otherwise, create Linux VM template with the [supported OS](https://www.ibm.com/support/knowledgecenter/en/SSBS6K_2.1.0/supported_system_config/supported_os.html) of your choice (Ubuntu/RHEL).  
5. The VM template should have:
- minimum disk size of 20GB
- configured with Ubuntu package manager or Red Hat subscription manager. If there is no internet connection, ensure that the VM template has all the pre-requisites pre-installed as defined in [Knowledge Center](https://www.ibm.com/support/knowledgecenter/en/SSBS6K_2.1.0)
6. SSH Private Key to access existing ICP boot node
7. Existing ICP Cluster information:
   - Boot node IP Address
   - Current worker nodes IP Addresses

## Deployment step from Terraform CLI
1. Clone this repository: `git clone https://github.com/pjgunadi/icp-add-worker.git`
2. [Download terraform](https://www.terraform.io/) if you don't have one
3. Rename [terraform_tfvars.sample](terraform_tfvars.sample) file as `terraform.tfvars` and update the input values as needed. 
4. Initialize Terraform
```
terraform init
```
5. Review Terraform plan
```
terraform plan
```
6. Apply Terraform template
```
terraform apply
```
**Note:**
You can also limit the concurrency with: `terraform apply -parallelism=x` where *x=number of concurrency*

## Add/Remove Worker Nodes
1. Edit existing deployed terraform variable e.g. `terraform.tfvars`
2. Increase/decrease the `nodes` and add/remove `ipaddresses` under the `worker` map variable. Example:
```
worker = {
    nodes       = "2"
    name        = "worker"
    cpu_cores   = "8"
    kubelet_lv  = "10"
    docker_lv   = "90"
    memory      = "8192"
    ipaddresses = "192.168.1.93,192.168.1.94"
    netmask     = "24"
    gateway     = "192.168.1.1"
}
```
**Note:** The data disk size is the sume of LV variables + 1 (e.g kubelet_lv + docker_lv + 1).  
2. Re-apply terraform template:
```
terraform plan
terraform apply -auto-approve
```
## Known Limitation
Existing worker nodes cannot be imported in Terraform as the imported vSphere node can't handle the [Clone block](https://github.com/terraform-providers/terraform-provider-vsphere/issues/333)

## Credit
The scaling script reuse existing scripts from [ibm-cloud-architecture/terraform-module-icp-deploy](https://github.com/ibm-cloud-architecture/terraform-module-icp-deploy)


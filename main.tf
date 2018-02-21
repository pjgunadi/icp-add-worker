provider "vsphere" {
  user           = "${var.vsphere_user}"
  password       = "${var.vsphere_password}"
  vsphere_server = "${var.vsphere_server}"
  allow_unverified_ssl = true
}

data "vsphere_datacenter" "dc" {
  name = "${var.datacenter}"
}

data "vsphere_datastore" "datastore" {
  count         = "${length(var.datastore)}"
  name          = "${element(var.datastore,count.index)}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_resource_pool" "pool" {
  name          = "${var.resource_pool}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_network" "network" {
  name          = "${var.network}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_virtual_machine" "template" {
  name          = "${lookup(var.template,var.osfamily)}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}
//Script template
data "template_file" "createfs_worker" {
  template = "${file("${path.module}/scripts/template/createfs_worker.sh.tpl")}"
  vars {
    kubelet_lv = "${var.worker["kubelet_lv"]}"
    docker_lv = "${var.worker["docker_lv"]}"
  }
}
//keyfiles
resource "null_resource" "public_keys" {
  provisioner "local-exec" {
    command = "ssh -i ${var.vm_private_key_file} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${var.ssh_user}@${var.icp_boot_node_ip} sudo ssh-keygen -y -f ${var.icp_private_key_file} | tee ${var.icp_public_key_file}"
  }
  provisioner "local-exec" {
    command = "ssh-keygen -y -f ${var.vm_private_key_file} | tee ${var.vm_public_key_file}"
  }
}
//locals
locals {
  icp_boot_node_ip = "${var.icp_boot_node_ip}"
  ssh_options = "-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
}
//worker
resource "vsphere_virtual_machine" "worker" {
  lifecycle {
    ignore_changes = ["disk.0","disk.1"]                                                                                                       
  }
  depends_on = ["null_resource.public_keys"]

  #count            = "${var.worker["nodes"]}"
  count            = "${trimspace(var.worker["ipaddresses"]) == "" ? 0 : length(split(",",var.worker["ipaddresses"]))}"  
  name             = "${format("%s-%s-%01d", lower(var.instance_prefix), lower(var.worker["name"]),count.index + 1) }"
  resource_pool_id = "${data.vsphere_resource_pool.pool.id}"
  datastore_id     = "${element(data.vsphere_datastore.datastore.*.id, ( count.index ) % length(var.datastore))}"

  num_cpus = "${var.worker["cpu_cores"]}"
  memory   = "${var.worker["memory"]}"
  guest_id = "${data.vsphere_virtual_machine.template.guest_id}"

  scsi_type = "${data.vsphere_virtual_machine.template.scsi_type}"

  network_interface {
    network_id   = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }

  disk {
    label            = "${format("%s-%s-%01d.vmdk", lower(var.instance_prefix), lower(var.worker["name"]),count.index + 1) }"
    size             = "${data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
  }

  disk {
    label            = "${format("%s-%s-%01d_1.vmdk", lower(var.instance_prefix), lower(var.worker["name"]),count.index + 1) }"
    size             = "${var.worker["kubelet_lv"] + var.worker["docker_lv"] + 1}"
    unit_number      = 1
    eagerly_scrub    = false
    thin_provisioned = false
  }

  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"

    customize {
      linux_options {
        host_name = "${format("%s-%s-%01d", lower(var.instance_prefix), lower(var.worker["name"]),count.index + 1) }"
        domain    = "${var.vm_domain}"
        time_zone = "${var.timezone}"
      }

      network_interface {
        ipv4_address = "${trimspace(element(split(",",var.worker["ipaddresses"]),count.index))}"
        ipv4_netmask = "${var.worker["netmask"]}"
      }

      ipv4_gateway = "${var.worker["gateway"]}"
      dns_server_list = "${var.dns_list}"
    }
  }

  connection {
    type = "ssh"
    user = "${var.ssh_user}"
    password = "${var.ssh_password}"
  }

  provisioner "file" {
    source = "${var.vm_public_key_file}"
    destination = "/tmp/${basename(var.vm_public_key_file)}"
  }
  provisioner "file" {
    content = "${data.template_file.createfs_worker.rendered}"
    destination = "/tmp/createfs.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "echo ${var.ssh_password} | sudo -S echo",
      "echo \"${var.ssh_user} ALL=(ALL) NOPASSWD:ALL\" | sudo tee /etc/sudoers.d/${var.ssh_user}",
      "sudo sed -i /^127.0.1.1.*$/d /etc/hosts",
      "[ ! -d $HOME/.ssh ] && mkdir $HOME/.ssh && chmod 700 $HOME/.ssh",
      "cat /tmp/${basename(var.vm_public_key_file)} | tee -a $HOME/.ssh/authorized_keys && chmod 600 $HOME/.ssh/authorized_keys",
      "[ -f ~/id_rsa ] && mv ~/id_rsa $HOME/.ssh/id_rsa && chmod 600 $HOME/.ssh/id_rsa",
      "chmod +x /tmp/createfs.sh; sudo /tmp/createfs.sh"
    ]
  }

  provisioner "file" {
      source = "${var.icp_public_key_file}"
      destination = "/tmp/${basename(var.icp_public_key_file)}"
  }
  provisioner "remote-exec" {
    inline = [
      "mkdir -p /tmp/icp-common-scripts"
    ]
  }
  provisioner "file" {
    source      = "${path.module}/scripts/common/"
    destination = "/tmp/icp-common-scripts"
  }
  provisioner "remote-exec" {
    inline = [
      "mkdir -p ~/.ssh",
      "cat /tmp/${basename(var.icp_public_key_file)} >> ~/.ssh/authorized_keys",
      "chmod a+x /tmp/icp-common-scripts/*",
      "/tmp/icp-common-scripts/prereqs.sh",
      "/tmp/icp-common-scripts/version-specific.sh ${var.icp_version}",
      "/tmp/icp-common-scripts/docker-user.sh",
      "/tmp/icp-common-scripts/download_installer.sh ${var.icp_source_server} ${var.icp_source_user} ${var.icp_source_password} ${var.icp_source_path} /tmp/${basename(var.icp_source_path)}"
    ]
  }

  provisioner "local-exec" {
    when    = "destroy"
    command = "scp -i ${var.vm_private_key_file} ${local.ssh_options} ${path.module}/scripts/boot/delete_worker.sh ${var.ssh_user}@${local.icp_boot_node_ip}:/tmp/delete_worker.sh"
  }
  provisioner "local-exec" {
    when    = "destroy"
    command = "ssh -i ${var.vm_private_key_file} ${local.ssh_options} ${var.ssh_user}@${local.icp_boot_node_ip} \"chmod +x /tmp/delete_worker.sh; /tmp/delete_worker.sh ${var.icp_version} ${self.default_ip_address}\"; echo done"
  }
}
//Add Worker from Boot Node
resource "null_resource" "icp-worker-scaler" {
  depends_on = ["null_resource.public_keys","vsphere_virtual_machine.worker"]
  
  triggers {
    workers = "${join(",", vsphere_virtual_machine.worker.*.default_ip_address)}"
  }
  
  connection {
    host = "${var.icp_boot_node_ip}"
    user = "${var.ssh_user}"
    private_key = "${file(var.vm_private_key_file)}"
  }

  provisioner "file" {
    content = "${join(",", var.existing_workers)}"
    destination = "/tmp/init_workerlist.txt"
  }

  provisioner "file" {
    content = "${join(",", concat(var.existing_workers,vsphere_virtual_machine.worker.*.default_ip_address))}"
    destination = "/tmp/icp_workerlist.txt"
  }

  provisioner "file" {
    source     = "${path.module}/scripts/boot/scale_icp_workers.sh"
    destination = "/tmp/scale_icp_workers.sh"
  }
  
  provisioner "remote-exec" {
    inline = [
      "[ -f ${var.icp_install_path}/icp_workerlist.txt ] || cp /tmp/init_workerlist.txt ${var.icp_install_path}/icp_workerlist.txt",
      "chmod a+x /tmp/scale_icp_workers.sh",
      "/tmp/scale_icp_workers.sh ${var.icp_version} ${var.icp_install_path}"
    ]
  }
}

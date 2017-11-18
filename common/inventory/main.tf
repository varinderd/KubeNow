variable cluster_prefix {}
variable ssh_user {}
variable domain {}

variable master_as_edge {}

variable master_hostnames {
  type = "list"
}

variable master_public_ip {
  type = "list"
}

variable master_private_ip {
  type = "list"
}

variable edge_count {}

variable edge_hostnames {
  type = "list"
}

variable edge_public_ip {
  type = "list"
}

variable edge_private_ip {
  type = "list"
}

variable node_count {}

variable node_hostnames {
  type = "list"
}

variable node_public_ip {
  type = "list"
}

variable node_private_ip {
  type = "list"
}

variable glusternode_count {}
variable gluster_volumetype {}
variable extra_disk_device {}

variable inventory_template_file {
  default = "inventory-template"
}

variable inventory_output_file {
  default = "inventory"
}

# create variables
locals {
  # Format list of masters
  masters = "${join("\n",formatlist("%s ansible_ssh_host=%s ansible_ssh_user=%s", var.master_hostnames , var.master_public_ip, var.ssh_user))}"
  
  # Format list of nodes
  nodes = "${join("\n",formatlist("%s ansible_ssh_host=%s ansible_ssh_user=%s", var.node_hostnames , var.node_public_ip, var.ssh_user))}"
  
  # Format list of nodes
  # Slice list to make sure hostname and ip-list have same length
  pure_edges = "${var.edge_count == 0 ? "" : join("\n",formatlist("%s ansible_ssh_host=%s ansible_ssh_user=${var.ssh_user}", slice(var.edge_hostnames,0,var.edge_count), var.edge_public_ip))}"
    
  # Add master to edges if that is the case
  edges = "${var.master_as_edge == true ? "${format("%s\n%s", local.masters, local.pure_edges)}" : local.pure_edges}"
    
  nodes_count = "${1 + var.edge_count + var.node_count + var.glusternode_count}"
}

# Generate inventory from template file
data "template_file" "inventory" {
  template = "${file("${path.root}/../${ var.inventory_template_file }")}"
  
  vars {
    masters            = "${local.masters}"
    nodes              = "${local.nodes}"
    edges              = "${local.edges}"
    nodes_count        = "${local.nodes_count}"
    domain             = "${var.domain}"
    extra_disk_device  = "${var.extra_disk_device}"
    glusternode_count  = "${var.glusternode_count}"
    gluster_volumetype = "${var.gluster_volumetype}"
  }
}

# Write the template to a file
resource "null_resource" "local" {
  # Trigger rewrite of inventory, uuid() generates a random string everytime it is called
  triggers {
    uuid = "${uuid()}"
  }

  triggers {
    template = "${data.template_file.inventory.rendered}"
  }

  provisioner "local-exec" {
    command = "echo '${data.template_file.inventory.rendered}' > \"${path.root}/../${var.inventory_output_file}\""
  }
}

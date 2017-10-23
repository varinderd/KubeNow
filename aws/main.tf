# Cluster settings
variable cluster_prefix {}

variable kubenow_image {
  default = "kubenow-v040b1"
}

variable kubeadm_token {}

variable aws_access_key_id {}
variable aws_secret_access_key {}
variable aws_region {}
variable availability_zone {}

variable ssh_user {
  default = "ubuntu"
}

variable ssh_key {
  default = "ssh_key.pub"
}

# Networking
variable vpc_id {
  default = ""
}

variable subnet_id {
  default = ""
}

variable additional_sec_group_ids {
  type = "list"

  default = []
}

# Master settings
variable master_count {
  default = 1
}

variable master_instance_type {}
variable master_disk_size {}

variable master_as_edge {
  default = "true"
}

# Nodes settings
variable node_count {}

variable node_instance_type {}
variable node_disk_size {}

# Edges settings
variable edge_count {
  default = 0
}

variable edge_instance_type {
  default = "nothing"
}

variable edge_disk_size {
  default = "nothing"
}

# Glusternode settings
variable glusternode_count {
  default = 0
}

variable glusternode_instance_type {
  default = "nothing"
}

variable glusternode_disk_size {
  default = "nothing"
}

variable glusternode_extra_disk_size {
  default = "200"
}

variable gluster_volumetype {
  default = "none:1"
}

# Cloudflare settings
variable use_cloudflare {
  default = "false"
}

variable cloudflare_email {
  default = "nothing"
}

variable cloudflare_token {
  default = "nothing"
}

variable cloudflare_domain {
  default = ""
}

variable cloudflare_proxied {
  default = "false"
}

variable cloudflare_record_texts {
  type    = "list"
  default = ["*"]
}

# Provider
provider "aws" {
  access_key = "${var.aws_access_key_id}"
  secret_key = "${var.aws_secret_access_key}"
  region     = "${var.aws_region}"
}

# Upload ssh-key to be used for access to the nodes
module "keypair" {
  source      = "./keypair"
  public_key  = "${var.ssh_key}"
  name_prefix = "${var.cluster_prefix}"
}

# Networking - VPC
module "vpc" {
  vpc_id      = "${var.vpc_id}"
  name_prefix = "${var.cluster_prefix}"
  source      = "./vpc"
}

# Networking - subnet
module "subnet" {
  subnet_id         = "${var.subnet_id}"
  vpc_id            = "${module.vpc.id}"
  name_prefix       = "${var.cluster_prefix}"
  availability_zone = "${var.availability_zone}"
  source            = "./subnet"
}

# Networking - sec-group
module "security_group" {
  name_prefix = "${var.cluster_prefix}"
  vpc_id      = "${module.vpc.id}"
  source      = "./security_group"
}

# Lookup image-id of kubenow-image
data "aws_ami" "kubenow" {
  most_recent = true

  filter {
    name   = "name"
    values = ["${var.kubenow_image}"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

variable "generic_nodes" {
  type = "list"
  default = [
    {
      node_count = "2"
      label      = "test1"
      public_ip  = "true"
    },
    {
      node_count = "1"
      label      = "test2"
      public_ip  = "false"
    }
  ]
}

module "generic" {
  # Core settings
  source            = "./generic"
  count             = "${length(var.generic_nodes)}"
  name_prefix       = "${lookup(var.generic_nodes[count.index], "node_count")}"

  instance_type     = "${var.master_instance_type}"
  image_id          = "${data.aws_ami.kubenow.id}"
  availability_zone = "${var.availability_zone}"

  # SSH settings
  ssh_user         = "${var.ssh_user}"
  ssh_keypair_name = "${module.keypair.keypair_name}"

  # Network settings
  subnet_id          = "${module.subnet.id}"
  security_group_ids = "${concat(module.security_group.id, var.additional_sec_group_ids)}"

  # Disk settings
  disk_size       = "${var.master_disk_size}"
  extra_disk_size = "0"

  # Bootstrap settings
  bootstrap_file = "bootstrap/master.sh"
  kubeadm_token  = "${var.kubeadm_token}"
  node_labels    = "${split(",", var.master_as_edge == "true" ? "role=edge" : "")}"
  node_taints    = [""]
  master_ip      = ""
}

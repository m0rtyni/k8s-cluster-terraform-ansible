variable "aws_region" {
  description = "AWS region for the Kubernetes cluster"
  type        = string
}

variable "availability_zone" {
  description = "Availability Zone for all Kubernetes nodes"
  type        = string
}

variable "project_name" {
  description = "Prefix used for AWS resource names and tags"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.project_name))
    error_message = "project_name must start with a lowercase letter and contain only lowercase letters, digits, and hyphens."
  }
}

variable "instance_type" {
  description = "EC2 instance type for Kubernetes nodes"
  type        = string
}

variable "nodes" {
  description = "Kubernetes nodes and their private IPv4 addresses"
  type = map(object({
    private_ip = string
    role       = string
  }))

  validation {
    condition     = length(var.nodes) == 3
    error_message = "This lab requires exactly three nodes."
  }

  validation {
    condition = (
      length([
        for node in values(var.nodes) : node
        if node.role == "control-plane"
      ]) == 1
    )
    error_message = "Exactly one node must have role control-plane."
  }

  validation {
    condition = (
      length([
        for node in values(var.nodes) : node
        if node.role == "worker"
      ]) == 2
    )
    error_message = "Exactly two nodes must have role worker."
  }
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidr" {
  description = "IPv4 CIDR block for the public subnet"
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "IPv4 CIDR allowed to access SSH"
  type        = string
}

variable "api_allowed_cidrs" {
  description = "IPv4 CIDR ranges allowed to access the Kubernetes API"
  type        = list(string)
}

variable "public_key_path" {
  description = "Path to the public SSH key, relative to the Terraform directory"
  type        = string
}

variable "key_pair_name" {
  description = "Name of the AWS EC2 key pair"
  type        = string
}

variable "ami_owner" {
  description = "AWS account ID that owns the Ubuntu AMI"
  type        = string
}

variable "ami_name_pattern" {
  description = "AMI name pattern for Ubuntu"
  type        = string
}

variable "ami_architecture" {
  description = "CPU architecture required for the AMI"
  type        = string
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB"
  type        = number

  validation {
    condition     = var.root_volume_size >= 20 && var.root_volume_size <= 100
    error_message = "root_volume_size must be between 20 and 100 GiB."
  }
}

variable "root_volume_type" {
  description = "EBS volume type for node root disks"
  type        = string
}

variable "common_tags" {
  description = "Tags applied to all managed AWS resources"
  type        = map(string)
}

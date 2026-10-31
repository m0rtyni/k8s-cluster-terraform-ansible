data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = [var.ami_owner]

  filter {
    name   = "name"
    values = [var.ami_name_pattern]
  }

  filter {
    name   = "architecture"
    values = [var.ami_architecture]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_vpc" "k8s" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-vpc"
  })
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.k8s.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-public-subnet"
  })
}

resource "aws_internet_gateway" "k8s" {
  vpc_id = aws_vpc.k8s.id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-igw"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.k8s.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.k8s.id
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "k8s" {
  name        = "${var.project_name}-sg"
  description = "Security group for manually bootstrapped Kubernetes"
  vpc_id      = aws_vpc.k8s.id

  ingress {
    description = "SSH from administrator"
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  ingress {
    description = "Kubernetes API from administrator"
    protocol    = "tcp"
    from_port   = 6443
    to_port     = 6443
    cidr_blocks = var.api_allowed_cidrs
  }

  ingress {
    description = "Traffic between cluster nodes"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    self        = true
  }

  egress {
    description = "Outbound internet access"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-sg"
  })
}

resource "aws_key_pair" "k8s" {
  key_name   = var.key_pair_name
  public_key = file(var.public_key_path)

  tags = var.common_tags
}

resource "aws_instance" "node" {
  for_each = var.nodes

  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.k8s.key_name
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.k8s.id]
  private_ip                  = each.value.private_ip
  associate_public_ip_address = true

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${each.key}"
    Role = each.value.role
  })
}

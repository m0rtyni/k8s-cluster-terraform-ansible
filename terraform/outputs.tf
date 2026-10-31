output "node_public_ips" {
  description = "Public IPv4 addresses of Kubernetes nodes"

  value = {
    for name, instance in aws_instance.node :
    name => instance.public_ip
  }
}

output "node_private_ips" {
  description = "Private IPv4 addresses of Kubernetes nodes"

  value = {
    for name, instance in aws_instance.node :
    name => instance.private_ip
  }
}

output "node_roles" {
  description = "Kubernetes role assigned to each node"
  value       = { for name, node in var.nodes : name => node.role }
}

output "ssh_user" {
  description = "Default SSH user for Ubuntu"
  value       = "ubuntu"
}

output "security_group_id" {
  description = "Security group ID for the cluster"
  value       = aws_security_group.k8s.id
}

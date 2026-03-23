output "aws_vpc_id" {
  value = local.vpc_id
}

output "aws_subnets_public" {
  value = local.subnets_public
}

output "aws_subnets_private" {
  value = local.subnets_private
}

output "aws_eks_ec2_ssh_keypair" {
  value = local.eks_ec2_ssh_keypair
}

output "aws_eks_ec2_ssh_privkey_file" {
  value = local.create_eks_ssh_keypair == true ? local_sensitive_file.ssh_private_key[0].filename : null
}

output "aws_eks_region" {
  value = var.aws_region
}

output "aws_eks_cluster_security_groups" {
  value = aws_eks_cluster.simple_eks.vpc_config[*].cluster_security_group_id
}

output "eks_cluster_node_ips" {
  value = zipmap(data.aws_instances.simple_eks_nodes.private_ips, data.aws_instances.simple_eks_nodes.public_ips)
}

output "eks_debug_instance_ip" {
  value = var.create_debug_instance ? aws_instance.eks_debug[0].public_ip : null
}

output "kubeconfig_certificate_authority_data" {
  value = aws_eks_cluster.simple_eks.certificate_authority[0].data
}

output "kubeconfig_eks_cluster_name" {
  value = aws_eks_cluster.simple_eks.name
}

output "kubeconfig_eks_cluster_endpoint" {
  value = aws_eks_cluster.simple_eks.endpoint
}

output "kubeconfig_rendered" {
  value = var.kubeconfig_write_output ? local.kubeconfig_rendered : null
  sensitive = true
}

output "kubeconfig_file_path" {
  value = var.kubeconfig_write_file ? local_sensitive_file.eks_kubeconfig[0].filename : null
}
data "aws_eks_cluster" "simple_eks" {
  name = var.cluster_name
}

data "aws_caller_identity" "eks_creator" {}

data "aws_region" "current" {}

locals {
  aws_account_id = data.aws_caller_identity.eks_creator.account_id
  aws_region = data.aws_region.current.region
  eks_cluster_identity_oidc = trimprefix("https://", data.aws_eks_cluster.simple_eks.identity[0].oidc[0].issuer)
  addon_configuration_values = [ ]
  addon_identity_service_account_roles = [
    {
      addon_name = "aws-ebs-csi-driver"
      role_arn = aws_iam_role.aws_ebs_csi_driver.arn
    }
  ]
  addon_identity_service_accounts = [
    {
      addon_name = "aws-ebs-csi-driver"
      service_account_name = "ebs-csi-controller-sa"
    }
  ]
}

resource "aws_eks_addon" "simple_eks" {
  for_each = toset(var.install_addons)
  cluster_name = data.aws_eks_cluster.simple_eks.name
  addon_name = each.key
  resolve_conflicts_on_update = "PRESERVE"
  configuration_values = one([for addon, config in local.addon_configuration_values : jsonencode(config) if addon == each.key])
  dynamic pod_identity_association {
    for_each = [for config in local.addon_identity_service_account_roles : config if config.addon_name == each.key]
    content {
      role_arn = pod_identity_association.value.role_arn
      service_account = one([for config in local.addon_identity_service_accounts : config.service_account_name if config.addon_name == each.key])
    }
  }
}

resource "aws_iam_role" "aws_ebs_csi_driver" {
  name = "aws-ebs-csi-driver-${var.unique_name_suffix}"
  assume_role_policy = data.aws_iam_policy_document.aws_ebs_csi_driver_assumerole.json
}

data "aws_iam_policy_document" "aws_ebs_csi_driver_assumerole" {
  statement {
    principals {
      type = "Service"
      identifiers = [ "pods.eks.amazonaws.com" ]
    }

    effect = "Allow"

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

resource "aws_iam_role_policy_attachment" "aws_ebs_csi_driver" {
  role = aws_iam_role.aws_ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "kubernetes_storage_class_v1" "aws_ebs_csi" {
  count = contains(var.install_addons, "aws-ebs-csi-driver") ? 1 : 0
  metadata {
    name = "ebs-csi"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = true
    }
  }
  storage_provisioner = "ebs.csi.aws.com"
  volume_binding_mode = "WaitForFirstConsumer"
  parameters = {
    type = "gp3"
    encrypted = true
  }
  depends_on = [ aws_eks_addon.simple_eks["aws-ebs-csi-driver"] ]
}

/*
Example additional resource structure for addons.  `example_data_source` could be a specific resource type like aws_iam_policy_document, or arbitrary data stored in a terraform_data resource.

resource "aws_example_resource" "addon_name" {
  count = contains(var.install_addons, "addon-name") ? 1 : 0
  string_parameter = "value"
  list_parameter = [ "value-1", "value-2" ]
  document_parameter = data.example_data_source.addon_name
  depends_on = [ aws_eks_addon["addon-name"] ]
}

data "example_data_source" "addon_name" {
  key = value
  other_key = other_value
}
*/
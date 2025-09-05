variable "install_addons" {
  description = "A list of addons that should be installed.  Valid values are any EKS addon name string.  If additional resources must be installed to support a desired addon, add them to main.tf as per the example resource in that file."
  type = list(string)
  default = [ "aws-ebs-csi-driver", "snapshot-controller", "eks-pod-identity-agent" ]
}

variable "cluster_name" {
  description = "The name of the cluster to install addons into."
  type = string
}
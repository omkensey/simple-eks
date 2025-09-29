variable "basic_addons" {
  description = "A list of addons that should be installed by default.  Valid values are any EKS addon name string.  If additional resources must be installed to support a desired addon, add them to main.tf as per the example resource in that file."
  type = list(string)
  nullable = false
  default = [ "aws-ebs-csi-driver", "snapshot-controller", "eks-pod-identity-agent", "metrics-server" ]
}

variable "extra_addons" {
  description = "A list of additional addons that should be installed.  Valid values are any EKS addon name string.  If additional resources must be installed to support a desired addon, add them to main.tf as per the example resource in that file."
  type = list(string)
  default = []
}

variable "cluster_name" {
  description = "The name of the cluster to install addons into."
  type = string
}

variable "unique_name_suffix" {
  type = string
}
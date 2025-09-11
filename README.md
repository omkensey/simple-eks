# simple-eks
A simple Terraform config to create a small EKS cluster suitable for demos and other non-prod uses.

> [!WARNING]
> Do not use this code for a production EKS cluster.  It is provided for educational purposes only, primarily for use preparing EKS clusters suitable for running demos.

## Basic structure:

If run with no customization of variables, this code will provision all of the following (some of these can be supplied by the user as inputs rather than created from scratch; see [Inputs and controls](#inputs-and-controls) below):

* A VPC
* Three public subnets
* Three private subnets
* An Internet gateway for public-subnet inbound and outbound traffic
* A NAT gateway for outbound private-subnet traffic
* An SSH keypair
* An EKS cluster with one EC2 node group
  * An IAM role for the cluster and one for the node group
  * An EKS access entry in the cluster to allow the user running this config to access the cluster through the AWS console
  * A set of basic addons (EBS CSI, CSI Snapshot, Pod Identity)
  * A default StorageClass using EBS CSI
* Security groups, security group rules, routing tables, routes to allow all of the above to function normally

Some inputs cause additional infrastructure and resources to be provisioned:

* Additional public or private subnnets
* Additional node group nodes
* A debug instance for investigating issues with EKS nodes in private subnets and security groups to allow basic access to it
* Additional EKS addons and access entries

## Inputs and controls:

Most variables are either obvious from the name (e.g. `aws_region`) or have a short description in `variables.tf`.  Some of the more useful ones to know are:

* **Kubernetes version**: You can specify a desired Kubernetes version with `eks_k8s_version`.  Valid versions (currently) look like 1.NN (e.g. the current default: `1.33`).  Any version string is accepted but a warning will be generated if the specified version is listed as extended-support or not currently listed as supported at all.  If no version is specified, EKS defaults to the latest supported version.

* **Kubeconfig output**: By default no kubeconfig is written or output.  If you want Terraform to render a kubeconfig that can be used by other tools or Terraform workspaces, set `kubeconfig_write_output` to write it as an output, and/or `kubeconfig_write_file` to write it as a file.  If you want to write the file to a specific path, specify it with `kubeconfig_file_path` (default: `files/kubeconfig.simple_eks`)
  * This is often not necessary as other Terraform workspaces can use the outputs of this one to retrieve the necessary authentication info directly, or running `aws eks update-kubeconfig` will write a kubeconfig.

* **Node group number and instance type**: The number of nodes in the node group is set by `eks_ec2_nodegroup_size` (default: `3`).  The instance type is set by `eks_ec2_nodegroup_instancetype` (default: `m5.large`).

* **Addons to install**: To install additional addons besides the default list (see below), pass a list of them in `eks_extra_addons` and they will be passed to (and installed by) the built-in `eks_addons` module.  Note that some addons require additional resources to function -- for an example of how to do that cleanly, see the resources in the `eks_addons` module that support the EBS CSI driver.

* **Existing VPC and subnets**: If you already have a VPC created, and/or subnets already created with appropriate networking, and want the new cluster to use those instead of new ones being created, you can supply their IDs as a list in the variables `aws_vpc_id`, `eks_subnets_public` and (optionally) `eks_subnets_private`.  In that case routing tables, security group rules and gateways, along with the associations between them, will *not* be created in the supplied subnets -- make sure you have already created the required network infrastructure.  Note that supplied VPC and subnet IDs will be used as-is, so make sure the subnets you supply are in the same VPC, and that is the VPC you supplied with `aws_vpc_id`, or your apply may fail.
  * In future, this config may auto-calculate the VPC ID from supplied subnet IDs to mitigate this requirement.

* **Private or public nodes**: The node group is created in private subnets by default.  To create it in public subnets, set `eks_nodegroup_public` to `false`.

* **Private-node debug jump host**: If you are setting up a cluster with the node group in private subnets, you may want to create a debug instance in the public subnet by setting `create_debug_instance` to `true`.  This will allow you to use the debug instance either directly as a host for debug utilities, or as a jump host to SSH to the private nodes (e.g. `ssh-add` the appropriate private key, then `ssh -i [private key] -A -J ec2-user@[debug instance public IP] ec2-user@[node private IP]`).

### Non-configurable cluster attributes:

The following items are not configurable without forking and customizing this config:

* Node type: EC2
* Number of node groups: 1
* Node OS type: Amazon Linux 2023 x86
* Capacity type: on-demand
* Authentication mode: API + ConfigMap
* Addons installed by default: Pod Identity Agent, EBS CSI Driver, CSI Snapshot
* Default StorageClass: EBS CSI

## Outputs

As with the input variables, most of the outputs have names that describe what they are.  Some of the more notable ones:

* **Infrastructure resources**: `aws_region`, `aws_vpc_id`, `aws_subnets_public` and `aws_subnets_private` are output to show the IDs of those resources which were used.  If you passed the IDs of an existing VPC or subnets in, these should be identical to what you supplied; otherwise, they will be the IDs of what was created.  These ouputs may be useful if you want to let this config create new resources from scratch and then refer to them in additional Terraform configs or other automation.

* **Access to EKS nodes**: The value of `aws_eks_ec2_ssh_keypair` will be the keypair name used for the EKS nodegroup (and the debug jump host, if one was created), and `aws_eks_ec2_ssh_privkey_file` will be the path to the generated private key file that corresponds to it, if a new keypair was created.  If a debug jump host was created, its public IP will be output in `eks_debug_instance_ip`.

* **Kubernetes API authentication info**: The basic cluster info needed for using the cluster's API (e.g. by other Terraform providers or by `kubectl`) is output in `kubeconfig_certificate_authority_data`, `kubeconfig_eks_cluster_name`, and `kubeconfig_eks_cluster_endpoint`.  Note that this does not include a token or token command, so these outputs are not inherently sensitive, but you will not be able to use these outputs by themselves to authenticate to the cluster.  You can, however, use the cluster name to [read an authentication token from the `aws_eks_cluster_auth` data source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster_auth) if another Terraform provider needs to authenticate to this cluster, or [use the AWS CLI to get the token](https://docs.aws.amazon.com/id_id/cli/latest/reference/eks/get-token.html) for other tools.

* **Ready-to-use kubeconfig**: If you set `kubeconfig_write_output` to `true`, the output `kubeconfig_rendered` will contain a fully-rendered kubeconfig that uses the `aws eks get-token` command to retrieve a temporary auth token.  (Note that this requires you to have currently-valid AWS credentials to use the kubeconfig.)  This output is not actually inherently sensitive since the authentication used is AWS rather than a directly-embedded token, but is masked as a sensitive output as basic good practice since kubeconfigs in general often do contain sensitive token or client-cert info.
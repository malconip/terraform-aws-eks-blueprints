data "aws_ssm_parameter" "ssm-vpc-id" {
  name = "/vpc/vpc-id"
}

data "aws_ssm_parameter" "ssm-prod-subnet-public-1" {
  name = "/vpc/prod-subnet-public-1"
}

data "aws_ssm_parameter" "ssm-prod-subnet-public-2" {
  name = "/vpc/prod-subnet-public-2"
}

resource "aws_kms_key" "eks" {
  description = "EKS Secret Encryption Key"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 18.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.22"

  cluster_endpoint_public_access = true

  cluster_addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {}
    vpc-cni = {
      resolve_conflicts = "OVERWRITE"
    }
  }

  cluster_encryption_config = [{
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }]

  vpc_id     = data.aws_ssm_parameter.ssm-vpc-id.value
  subnet_ids = [data.aws_ssm_parameter.ssm-prod-subnet-public-1.value, data.aws_ssm_parameter.ssm-prod-subnet-public-2.value]

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    disk_size      = 8
    instance_types = ["t2.micro"]
  }

  eks_managed_node_groups = {
    blue = {}
    green = {
      min_size     = 1
      max_size     = 3
      desired_size = 1

      instance_types = ["t2.micro"]
      capacity_type  = "ON_DEMAND"
    }
  }

  # aws-auth configmap
  manage_aws_auth_configmap = true

  aws_auth_users = [
    {
      userarn  = "arn:aws:iam::944385918504:user/root"
      username = "root"
      groups   = ["system:masters"]
    },
    {
      userarn  = "arn:aws:iam::944385918504:user/vader"
      username = "vader"
      groups   = ["system:masters"]
    },
  ]

  aws_auth_accounts = [
    "944385918504"
  ]

  tags = {
    Environment = "prod"
    Terraform   = "true"
  }
}

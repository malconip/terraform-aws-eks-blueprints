data "aws_ssm_parameter" "ssm-vpc-id" {
  name = "/vpc/vpc-id"
}

data "aws_ssm_parameter" "ssm-prod-subnet-public-1" {
  name = "/vpc/prod-subnet-public-1"
}

data "aws_ssm_parameter" "ssm-prod-subnet-public-2" {
  name = "/vpc/prod-subnet-public-2"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 18.0"

  cluster_name    = "odin"
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
    provider_key_arn = "ac01234b-00d9-40f6-ac95-e42345f78b00"
    resources        = ["secrets"]
  }]

  vpc_id     = data.aws_ssm_parameter.ssm-vpc-id.value
  subnet_ids = [data.aws_ssm_parameter.ssm-prod-subnet-public-1.value, data.aws_ssm_parameter.ssm-prod-subnet-public-2.value]

  # Self Managed Node Group(s)
  self_managed_node_group_defaults = {
    instance_type                          = "t2.micro"
    update_launch_template_default_version = true
    iam_role_additional_policies = [
      "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    ]
  }

  self_managed_node_groups = {
    one = {
      name         = "mixed-1"
      max_size     = 3
      desired_size = 1

      use_mixed_instances_policy = true
      mixed_instances_policy = {
        instances_distribution = {
          on_demand_base_capacity                  = 100
          on_demand_percentage_above_base_capacity = 0
          spot_allocation_strategy                 = "capacity-optimized"
        }

        override = [
          {
            instance_type     = "t2.micro"
            weighted_capacity = "1"
          }
        ]
      }
    }
  }

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

  # Fargate Profile(s)
  fargate_profiles = {
    default = {
      name = "default"
      selectors = [
        {
          namespace = "default"
        }
      ]
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

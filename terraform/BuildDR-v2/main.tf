terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "aws" {
  # AWS Region will be picked up from AWS_REGION / AWS_DEFAULT_REGION or AWS CLI profile
}

# ── Random Suffix (matches CFN StackId short suffix) ───────────────────────────
resource "random_id" "suffix" {
  byte_length = 4
}

# ── Data Sources ──────────────────────────────────────────────────────────────
data "aws_region" "current" {}

# ── Variables (Converted from CloudFormation Parameters) ──────────────────────
variable "network_stack_name" {
  type        = string
  description = "Name of the network stack to import values from (if using CloudFormation exports)"
  default     = "network-stack"
}

variable "db_host" {
  type        = string
  description = "Aurora cluster endpoint (MANDATORY)"
}

variable "s3_bucket_name" {
  type        = string
  description = "Existing S3 bucket name for product images (MANDATORY)"
}

variable "ami_id" {
  type        = string
  description = "AMI ID for EC2 instances in the ASG (MANDATORY)"
}

variable "db_password" {
  type        = string
  description = "Aurora database password"
  default     = "demoPassword"
  sensitive   = true
}

variable "db_username" {
  type        = string
  description = "Aurora database master username"
  default     = "dbadmin"
}

variable "db_name" {
  type        = string
  description = "Aurora database name"
  default     = "demo"
}

variable "app_port" {
  type        = number
  description = "Application port"
  default     = 3001
}

# Optional direct inputs for network resources (if not relying on CFN exports)
variable "use_cfn_exports" {
  type        = bool
  description = "Whether to fetch network resources from CloudFormation exports"
  default     = true
}

variable "vpc_id" {
  type        = string
  description = "VPC ID (optional override for CFN export)"
  default     = null
}

variable "public_subnet_a_id" {
  type        = string
  description = "Public Subnet A ID (optional override for CFN export)"
  default     = null
}

variable "public_subnet_b_id" {
  type        = string
  description = "Public Subnet B ID (optional override for CFN export)"
  default     = null
}

variable "app_subnet_a_id" {
  type        = string
  description = "App Subnet A ID (optional override for CFN export)"
  default     = null
}

variable "app_subnet_b_id" {
  type        = string
  description = "App Subnet B ID (optional override for CFN export)"
  default     = null
}

variable "private_route_table_id" {
  type        = string
  description = "Private Route Table ID (optional override for CFN export)"
  default     = null
}

variable "alb_security_group_id" {
  type        = string
  description = "ALB Security Group ID (optional override for CFN export)"
  default     = null
}

variable "app_security_group_id" {
  type        = string
  description = "App Security Group ID (optional override for CFN export)"
  default     = null
}

# ── CloudFormation Export Lookups (!ImportValue) ───────────────────────────────
data "aws_cloudformation_export" "vpc_id" {
  count = var.use_cfn_exports && var.vpc_id == null ? 1 : 0
  name  = "${var.network_stack_name}-VPCId"
}

data "aws_cloudformation_export" "public_subnet_a" {
  count = var.use_cfn_exports && var.public_subnet_a_id == null ? 1 : 0
  name  = "${var.network_stack_name}-PublicSubnetA"
}

data "aws_cloudformation_export" "public_subnet_b" {
  count = var.use_cfn_exports && var.public_subnet_b_id == null ? 1 : 0
  name  = "${var.network_stack_name}-PublicSubnetB"
}

data "aws_cloudformation_export" "app_subnet_a" {
  count = var.use_cfn_exports && var.app_subnet_a_id == null ? 1 : 0
  name  = "${var.network_stack_name}-AppSubnetA"
}

data "aws_cloudformation_export" "app_subnet_b" {
  count = var.use_cfn_exports && var.app_subnet_b_id == null ? 1 : 0
  name  = "${var.network_stack_name}-AppSubnetB"
}

data "aws_cloudformation_export" "private_rt_id" {
  count = var.use_cfn_exports && var.private_route_table_id == null ? 1 : 0
  name  = "${var.network_stack_name}-PrivateRTId"
}

data "aws_cloudformation_export" "alb_security_group" {
  count = var.use_cfn_exports && var.alb_security_group_id == null ? 1 : 0
  name  = "${var.network_stack_name}-ALBSecurityGroup"
}

data "aws_cloudformation_export" "app_security_group" {
  count = var.use_cfn_exports && var.app_security_group_id == null ? 1 : 0
  name  = "${var.network_stack_name}-AppSecurityGroup"
}

locals {
  vpc_id                = var.vpc_id != null ? var.vpc_id : (length(data.aws_cloudformation_export.vpc_id) > 0 ? data.aws_cloudformation_export.vpc_id[0].value : null)
  public_subnet_a_id    = var.public_subnet_a_id != null ? var.public_subnet_a_id : (length(data.aws_cloudformation_export.public_subnet_a) > 0 ? data.aws_cloudformation_export.public_subnet_a[0].value : null)
  public_subnet_b_id    = var.public_subnet_b_id != null ? var.public_subnet_b_id : (length(data.aws_cloudformation_export.public_subnet_b) > 0 ? data.aws_cloudformation_export.public_subnet_b[0].value : null)
  app_subnet_a_id       = var.app_subnet_a_id != null ? var.app_subnet_a_id : (length(data.aws_cloudformation_export.app_subnet_a) > 0 ? data.aws_cloudformation_export.app_subnet_a[0].value : null)
  app_subnet_b_id       = var.app_subnet_b_id != null ? var.app_subnet_b_id : (length(data.aws_cloudformation_export.app_subnet_b) > 0 ? data.aws_cloudformation_export.app_subnet_b[0].value : null)
  private_rt_id         = var.private_route_table_id != null ? var.private_route_table_id : (length(data.aws_cloudformation_export.private_rt_id) > 0 ? data.aws_cloudformation_export.private_rt_id[0].value : null)
  alb_security_group_id = var.alb_security_group_id != null ? var.alb_security_group_id : (length(data.aws_cloudformation_export.alb_security_group) > 0 ? data.aws_cloudformation_export.alb_security_group[0].value : null)
  app_security_group_id = var.app_security_group_id != null ? var.app_security_group_id : (length(data.aws_cloudformation_export.app_security_group) > 0 ? data.aws_cloudformation_export.app_security_group[0].value : null)
}

# ── NAT Gateway ───────────────────────────────────────────────────────────────
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "inventory-nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = local.public_subnet_a_id

  tags = {
    Name = "inventory-nat"
  }
}

resource "aws_route" "nat_route" {
  route_table_id         = local.private_rt_id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

# ── IAM Role for EC2 ──────────────────────────────────────────────────────────
resource "aws_iam_role" "ec2_role" {
  name = "inventory-ec2-role-${random_id.suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "s3_image_access" {
  name = "S3ImageAccess"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::${var.s3_bucket_name}/products/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "inventory-ec2-profile-${random_id.suffix.hex}"
  role = aws_iam_role.ec2_role.name
}

# ── ALB ───────────────────────────────────────────────────────────────────────
resource "aws_lb" "alb" {
  name               = "inventory-alb-${random_id.suffix.hex}"
  internal           = false
  load_balancer_type = "application"
  subnets            = [local.public_subnet_a_id, local.public_subnet_b_id]
  security_groups    = [local.alb_security_group_id]

  tags = {
    Name = "inventory-alb"
  }
}

resource "aws_lb_target_group" "alb_target_group" {
  name        = "inventory-tg-${random_id.suffix.hex}"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  target_type = "instance"

  health_check {
    path                = "/api/products"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "inventory-tg"
  }
}

resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_target_group.arn
  }
}

# ── Launch Template & ASG ─────────────────────────────────────────────────────
resource "aws_launch_template" "launch_template" {
  name          = "inventory-lt-${random_id.suffix.hex}"
  image_id      = var.ami_id
  instance_type = "t4g.micro"

  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2_instance_profile.arn
  }

  vpc_security_group_ids = [local.app_security_group_id]

  user_data = base64encode(<<-EOF
#!/bin/bash
printf 'DB_HOST=%s\nDB_PORT=5432\nDB_USER=%s\nDB_PASSWORD=%s\nPORT=%s\nS3_BUCKET=%s\nAWS_REGION=%s\n' \
  "${var.db_host}" \
  "${var.db_username}" \
  "${var.db_password}" \
  "${var.app_port}" \
  "${var.s3_bucket_name}" \
  "${data.aws_region.current.name}" \
  > /home/ec2-user/architecting/.env
systemctl restart demo-app
EOF
  )

  tags = {
    Name = "inventory-lt"
  }
}

resource "aws_autoscaling_group" "asg" {
  name                = "inventory-asg-${random_id.suffix.hex}"
  min_size            = 1
  max_size            = 4
  desired_capacity    = 2
  vpc_zone_identifier = [local.app_subnet_a_id, local.app_subnet_b_id]
  target_group_arns   = [aws_lb_target_group.alb_target_group.arn]

  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.launch_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "inventory-app"
    propagate_at_launch = true
  }

  depends_on = [aws_nat_gateway.nat]
}

# ── Outputs ───────────────────────────────────────────────────────────────────
output "alb_url" {
  description = "Application URL"
  value       = "http://${aws_lb.alb.dns_name}"
}

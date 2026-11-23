# ── Variables (Converted from CloudFormation Parameters) ──────────────────────
variable "db_name" {
  type        = string
  description = "Database name for Aurora PostgreSQL"
  default     = "demo"
}

variable "db_username" {
  type        = string
  description = "Master username for Aurora PostgreSQL"
  default     = "dbadmin"
}

variable "db_password" {
  type        = string
  description = "Master password for Aurora PostgreSQL"
  default     = "demoPassword"
  sensitive   = true
}

variable "app_port" {
  type        = number
  description = "Application port"
  default     = 3001
}

variable "git_repo" {
  type        = string
  description = "Git repository containing the application code"
  default     = "https://github.com/longdominh00-milo/longdmaws.git"
}

variable "git_branch" {
  type        = string
  description = "Git branch to clone"
  default     = "lab17-dr"
}

variable "ami_id" {
  type        = string
  description = "Custom AMI ID for EC2 instances in ASG. If null, uses the SSM parameter value."
  default     = null
}

variable "ami_ssm_parameter" {
  type        = string
  description = "SSM Parameter path for Amazon Linux 2023 ARM64 AMI"
  default     = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

locals {
  ami_id = var.ami_id != null ? var.ami_id : data.aws_ssm_parameter.al2023_arm64.value

  # Subnet CIDR mapping corresponding to CFN Mappings.SubnetConfig
  subnet_config = {
    vpc      = "10.0.0.0/16"
    public_a = "10.0.1.0/24"
    public_b = "10.0.2.0/24"
    app_a    = "10.0.11.0/24"
    app_b    = "10.0.12.0/24"
    db_a     = "10.0.21.0/24"
    db_b     = "10.0.22.0/24"
  }
}

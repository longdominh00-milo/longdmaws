provider "aws" {
  # AWS Region will be picked up from AWS_REGION / AWS_DEFAULT_REGION or AWS CLI profile
}

# ── Random Suffix (matches CFN StackId short suffix) ───────────────────────────
resource "random_id" "suffix" {
  byte_length = 4
}

# ── Data Sources ──────────────────────────────────────────────────────────────
data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ssm_parameter" "al2023_arm64" {
  name = var.ami_ssm_parameter
}

# ── VPC & Internet Gateway ────────────────────────────────────────────────────
resource "aws_vpc" "vpc" {
  cidr_block           = local.subnet_config.vpc
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "lab17-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "lab17-igw"
  }
}

# ── Subnets ───────────────────────────────────────────────────────────────────
# Public Subnets
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = local.subnet_config.public_a
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = local.subnet_config.public_b
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-b"
  }
}

# App Private Subnets
resource "aws_subnet" "app_a" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = local.subnet_config.app_a
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "app-a"
  }
}

resource "aws_subnet" "app_b" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = local.subnet_config.app_b
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "app-b"
  }
}

# DB Private Subnets
resource "aws_subnet" "db_a" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = local.subnet_config.db_a
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "db-a"
  }
}

resource "aws_subnet" "db_b" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = local.subnet_config.db_b
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "db-b"
  }
}

# ── NAT Gateway (single, AZ-a) ────────────────────────────────────────────────
resource "aws_eip" "nat_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "lab17-nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name = "lab17-natgw"
  }
}

# ── Route Tables ──────────────────────────────────────────────────────────────
# Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "public-rtb"
  }
}

resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public_rt.id
}

# Private Route Table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "private-rtb"
  }
}

resource "aws_route" "private_route" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "app_a" {
  subnet_id      = aws_subnet.app_a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "app_b" {
  subnet_id      = aws_subnet.app_b.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "db_a" {
  subnet_id      = aws_subnet.db_a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "db_b" {
  subnet_id      = aws_subnet.db_b.id
  route_table_id = aws_route_table.private_rt.id
}

# ── Security Groups ───────────────────────────────────────────────────────────
# ALB Security Group
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg-${random_id.suffix.hex}"
  description = "ALB - allow HTTP from internet"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["27.66.99.166/32"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "alb-sg"
  }
}

# App Security Group
resource "aws_security_group" "app_sg" {
  name        = "app-sg-${random_id.suffix.hex}"
  description = "App EC2 - allow from ALB"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "app-sg"
  }
}

# Aurora DB Security Group
resource "aws_security_group" "db_sg" {
  name        = "db-sg-${random_id.suffix.hex}"
  description = "Aurora - allow from App"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "db-sg"
  }
}

# ── S3 Bucket ─────────────────────────────────────────────────────────────────
resource "aws_s3_bucket" "image_bucket" {
  bucket        = "lab17-images-${random_id.suffix.hex}"
  force_destroy = true

  tags = {
    Name = "lab17-images"
  }
}

resource "aws_s3_bucket_public_access_block" "image_bucket" {
  bucket = aws_s3_bucket.image_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_cors_configuration" "image_bucket" {
  bucket = aws_s3_bucket.image_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT"]
    allowed_origins = ["*"]
    max_age_seconds = 3600
  }
}

# ── IAM Role for EC2 ──────────────────────────────────────────────────────────
resource "aws_iam_role" "ec2_role" {
  name = "lab17-ec2-role-${random_id.suffix.hex}"

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
        Resource = "${aws_s3_bucket.image_bucket.arn}/products/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "lab17-ec2-profile-${random_id.suffix.hex}"
  role = aws_iam_role.ec2_role.name
}

# ── Aurora PostgreSQL ─────────────────────────────────────────────────────────
resource "aws_db_subnet_group" "db_subnet_group" {
  name        = "aurora-db-subnet-group-${random_id.suffix.hex}"
  description = "Aurora DB subnet group"
  subnet_ids  = [aws_subnet.db_a.id, aws_subnet.db_b.id]

  tags = {
    Name = "aurora-db-subnet-group"
  }
}

resource "aws_rds_cluster" "aurora_cluster" {
  cluster_identifier      = "lab17-aurora-cluster-${random_id.suffix.hex}"
  engine                  = "aurora-postgresql"
  engine_version          = "16.6"
  database_name           = var.db_name
  master_username         = var.db_username
  master_password         = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.db_sg.id]
  storage_encrypted       = true
  backup_retention_period = 1
  skip_final_snapshot     = true

  tags = {
    Name = "inventory-aurora-cluster"
  }
}

resource "aws_rds_cluster_instance" "aurora_instance" {
  identifier           = "my-aurora-instance-1"
  cluster_identifier   = aws_rds_cluster.aurora_cluster.id
  instance_class       = "db.t4g.medium"
  engine               = aws_rds_cluster.aurora_cluster.engine
  engine_version       = aws_rds_cluster.aurora_cluster.engine_version
  db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name
  publicly_accessible  = false

  tags = {
    Name = "my-aurora-instance-1"
  }
}

# ── ALB ───────────────────────────────────────────────────────────────────────
resource "aws_lb" "alb" {
  name               = "lab17-alb-${random_id.suffix.hex}"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  security_groups    = [aws_security_group.alb_sg.id]

  tags = {
    Name = "lab17-alb"
  }
}

resource "aws_lb_target_group" "alb_target_group" {
  name        = "lab17-tg-${random_id.suffix.hex}"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc.id
  target_type = "instance"

  health_check {
    path                = "/api/products"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "lab17-tg"
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
  name          = "lab17-lt-${random_id.suffix.hex}"
  image_id      = local.ami_id
  instance_type = "t4g.micro"

  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2_instance_profile.arn
  }

  vpc_security_group_ids = [aws_security_group.app_sg.id]

  user_data = base64encode(<<-EOF
#!/bin/bash
exec > >(tee /var/log/userdata.log) 2>&1

# Install dependencies
dnf update -y
dnf install -y git postgresql17
dnf module enable -y nodejs:22 || true
dnf install -y nodejs

# Clone app
cd /home/ec2-user
git clone -b ${var.git_branch} ${var.git_repo} 
cd longdmaws
npm install

# Write env file using printf to avoid heredoc indentation issues
printf 'DB_HOST=%s\nDB_PORT=5432\nDB_USER=%s\nDB_PASSWORD=%s\nPORT=%s\nS3_BUCKET=%s\nAWS_REGION=%s\n' \
  "${aws_rds_cluster.aurora_cluster.endpoint}" \
  "${var.db_username}" \
  "${var.db_password}" \
  "${var.app_port}" \
  "${aws_s3_bucket.image_bucket.id}" \
  "${data.aws_region.current.name}" \
  > /home/ec2-user/longdmaws/.env

chown -R ec2-user:ec2-user /home/ec2-user/longdmaws

# Create systemd service using printf to avoid indentation issues
printf '[Unit]\nDescription=Inventory Management Application\nAfter=network.target\n\n[Service]\nType=simple\nUser=ec2-user\nWorkingDirectory=/home/ec2-user/architecting\nEnvironmentFile=/home/ec2-user/architecting/.env\nExecStart=/usr/bin/node server.js\nRestart=always\nRestartSec=10\nStandardOutput=journal\nStandardError=journal\nSyslogIdentifier=demo-app\n\n[Install]\nWantedBy=multi-user.target\n' \
  > /etc/systemd/system/demo-app.service

systemctl daemon-reload
systemctl enable demo-app
systemctl start demo-app

# ── DB init & seed (idempotent) ───────────────────────────────────
export PGPASSWORD="${var.db_password}"
DB_HOST="${aws_rds_cluster.aurora_cluster.endpoint}"
DB_USER="${var.db_username}"
DB_NAME="${var.db_name}"

# Wait up to 5 min for Aurora to accept connections
for i in $(seq 1 20); do
  psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1" > /dev/null 2>&1 && break
  echo "Waiting for DB... attempt $i"
  sleep 15
done

# Create table
psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" \
  -c "CREATE TABLE IF NOT EXISTS products (id SERIAL PRIMARY KEY, name VARCHAR(255) NOT NULL, qty INTEGER NOT NULL DEFAULT 0, image_url VARCHAR(1024));"
EOF
  )

  tags = {
    Name = "lab17-lt"
  }
}

resource "aws_autoscaling_group" "asg" {
  name                = "lab17-asg-${random_id.suffix.hex}"
  min_size            = 1
  max_size            = 4
  desired_capacity    = 2
  vpc_zone_identifier = [aws_subnet.app_a.id, aws_subnet.app_b.id]
  target_group_arns   = [aws_lb_target_group.alb_target_group.arn]

  health_check_type         = "ELB"
  health_check_grace_period = 60

  launch_template {
    id      = aws_launch_template.launch_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "lab17-app"
    propagate_at_launch = true
  }

  depends_on = [
    aws_nat_gateway.nat,
    aws_rds_cluster_instance.aurora_instance
  ]
}

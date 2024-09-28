provider "aws" {
  region = "us-west-1"
}

### VARIABLES ###
variable "key_name" {
  description = "SSH key used to access your instances"
}

variable "my_ip" {
  description = "Your ip address"
}

variable "db_name" {
  description = "RDS database name"
}

variable "rds_user" {
  description = "Username for your RDS user"
}

variable "rds_password" {
  description = "Password for your RDS user"
}

variable "git_token" {
  description = "Git token used to pull code down"
}

variable "availability_zone_1" {
  description = "First AZ that you'll operate out of"
}

variable "availability_zone_2" {
  description = "Second AZ that you'll operate out of"
}

output "bastion_host_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

### NETWORKING ###
resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/25"

  tags = {
    Name = "Expense Tracker VPC"
  }
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.0.0/28"
  availability_zone       = var.availability_zone_1
  map_public_ip_on_launch = true

  tags = {
    Name = "Expense Tracker Public Subnet 1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.0.16/28"
  availability_zone       = var.availability_zone_2
  map_public_ip_on_launch = true

  tags = {
    Name = "Expense Tracker Public Subnet 2"
  }
}

resource "aws_subnet" "compute_1" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.0.32/28"
  availability_zone = var.availability_zone_1

  tags = {
    Name = "Expense Tracker Compute Subnet 1"
  }
}

resource "aws_subnet" "compute_2" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.0.48/28"
  availability_zone = var.availability_zone_2

  tags = {
    Name = "Expense Tracker Compute Subnet 2"
  }
}

resource "aws_subnet" "db" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.0.64/28"
  availability_zone = var.availability_zone_1

  tags = {
    Name = "Expense Tracker DB Subnet 1"
  }
}

resource "aws_subnet" "db_2" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.0.80/28"
  availability_zone = var.availability_zone_2

  tags = {
    Name = "Expense Tracker DB Subnet 2"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "Expense Tracker IGW"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "this" {
  subnet_id     = aws_subnet.public_1.id
  allocation_id = aws_eip.nat.id

  tags = {
    Name = "Expense Tracker NAT GW"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "compute" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }
}

resource "aws_route_table_association" "compute_1" {
  subnet_id      = aws_subnet.compute_1.id
  route_table_id = aws_route_table.compute.id
}

resource "aws_route_table_association" "compute_2" {
  subnet_id      = aws_subnet.compute_2.id
  route_table_id = aws_route_table.compute.id
}

### SERVICES ###
resource "aws_instance" "bastion" {
  ami                    = "ami-0d53d72369335a9d6"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_1.id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.bastion.id]

  tags = {
    Name = "Expense Tracker Bastion Host"
  }
}

resource "aws_security_group" "bastion" {
  name        = "expense_tracker_bastion_host_sg"
  description = "SG rules for the Expense Tracker Bastion Host"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "app" {
  name        = "expense_tracker_app_host_sg"
  description = "SG rules for the Expense Tracker App Host"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/25"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/25"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/25"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

## LB
resource "aws_lb" "this" {
  name               = "expense-tracker-lb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  tags = {
    Name = "Expense Tracker"
  }
}

resource "aws_security_group" "alb" {
  name        = "expense_tracker_alb_sg"
  description = "Security group for the Expense Tracker ALB"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

## LISTENERS
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.this.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.front_end.arn
  }
}

resource "aws_lb_listener" "back_end" {
  load_balancer_arn = aws_lb.this.arn
  port              = "3000"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.back_end.arn
  }
}

## TG
resource "aws_lb_target_group" "front_end" {
  name     = "expense-tracker-frontend-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.this.id

  health_check {
    interval = 5
    timeout  = 2
    path     = "/"
  }
}

resource "aws_lb_target_group" "back_end" {
  name     = "expense-tracker-backend-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = aws_vpc.this.id

  health_check {
    interval = 5
    timeout  = 2
    path     = "/health"
  }
}

## ASG
resource "aws_launch_template" "expense_tracker" {
  name = "expense-tracker-lt"
  image_id = "ami-0d53d72369335a9d6"
  instance_type = "t2.micro"
  key_name = "m3-mb-pro"
  vpc_security_group_ids = [aws_security_group.app.id]
  user_data = base64encode(file("./scripts/setup.sh"))
  
  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2_ssm_instance_profile.arn
  }

  tags = {
    Name = "Expense Tracker Launch Template"
  }
}

resource "aws_autoscaling_group" "this" {
  name = "expense-tracker-asg"
  min_size = 1
  max_size = 1
  desired_capacity = 1
  health_check_grace_period = 900
  health_check_type = "ELB"
  vpc_zone_identifier = [ aws_subnet.compute_1.id, aws_subnet.compute_2.id ]
  target_group_arns = [aws_lb_target_group.front_end.arn, aws_lb_target_group.back_end.arn]
  depends_on = [ aws_db_instance.this ]
  launch_template {
    id = aws_launch_template.expense_tracker.id
    version = "$Latest"
  }

  tag {
    key = "Name"
    value = "Expense Tracker App Host"
    propagate_at_launch = true
  }
}

### DATA ###
resource "aws_db_instance" "this" {
  allocated_storage      = 20
  db_name                = var.db_name
  engine                 = "postgres"
  instance_class         = "db.t3.micro"
  username               = var.rds_user
  password               = var.rds_password
  skip_final_snapshot    = true
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  identifier             = "expense-tracker-rds-instance"
}

resource "aws_db_subnet_group" "this" {
  subnet_ids = [aws_subnet.db.id, aws_subnet.db_2.id]

  tags = {
    Name = "Expense Tracker RDS Subnet Group"
  }
}

resource "aws_security_group" "db" {
  name        = "rds_sg"
  description = "SG rules for the Expense Tracker RDS Database"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.compute_1.cidr_block, aws_subnet.compute_2.cidr_block]
  }
}

### SECRETS ###
resource "aws_ssm_parameter" "git_token" {
  name        = "/expense-tracker/git-token"
  description = "Git token used to pull the application code"
  type        = "SecureString"
  value       = var.git_token

  tags = {
    Name = "Expense Tracker Git Token"
  }
}

resource "aws_ssm_parameter" "rds_user" {
  name        = "/expense-tracker/rds-user"
  description = "User for RDS database"
  type        = "SecureString"
  value       = var.rds_user

  tags = {
    Name = "Expense Tracker RDS User"
  }
}

resource "aws_ssm_parameter" "rds_password" {
  name        = "/expense-tracker/rds-password"
  description = "Password for RDS database"
  type        = "SecureString"
  value       = var.rds_password

  tags = {
    Name = "Expense Tracker RDS Password"
  }
}

resource "aws_ssm_parameter" "rds_db_name" {
  name        = "/expense-tracker/rds-db-name"
  description = "RDS database name"
  type        = "SecureString"
  value       = var.db_name

  tags = {
    Name = "Expense Tracker RDS DB Name"
  }
}

### PERMISSIONS ###
resource "aws_iam_role" "ssm_role" {
  name = "ec2_ssm_access_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "ssm_policy" {
  name        = "ssm_parameter_store_policy"
  description = "Policy to allow EC2 access to SSM Parameter Store"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action   = ["rds:DescribeDBInstances"],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action   = ["elasticloadbalancing:DescribeLoadBalancers"],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_ssm_policy" {
  policy_arn = aws_iam_policy.ssm_policy.arn
  role       = aws_iam_role.ssm_role.name
}

resource "aws_iam_instance_profile" "ec2_ssm_instance_profile" {
  name = "ec2_ssm_instance_profile"
  role = aws_iam_role.ssm_role.name
}
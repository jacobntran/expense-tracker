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

output "bastion_host_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "app_host_private_ip" {
  value = aws_instance.app.private_ip
}

### NETWORKING ###
resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/26"

  tags = {
    Name = "Expense Tracker VPC"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.0.0/28"
  availability_zone       = "us-west-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "Expense Tracker Public Subnet"
  }
}

resource "aws_subnet" "compute" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.0.16/28"
  availability_zone = "us-west-1b"

  tags = {
    Name = "Expense Tracker Compute Subnet"
  }
}

resource "aws_subnet" "db" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.0.32/28"
  availability_zone = "us-west-1b"

  tags = {
    Name = "Expense Tracker DB Subnet 1"
  }
}

resource "aws_subnet" "db_2" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.0.48/28"
  availability_zone = "us-west-1c"

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
  subnet_id     = aws_subnet.public.id
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

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "compute" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }
}

resource "aws_route_table_association" "compute" {
  subnet_id      = aws_subnet.compute.id
  route_table_id = aws_route_table.compute.id
}

### SERVICES ###
resource "aws_instance" "bastion" {
  ami                    = "ami-0d53d72369335a9d6"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public.id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.bastion.id]

  tags = {
    Name = "Expense Tracker Bastion Host"
  }
}

resource "aws_instance" "app" {
  ami                    = "ami-0d53d72369335a9d6"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.compute.id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.app.id]

  tags = {
    Name = "Expense Tracker Application Host"
  }
}

resource "aws_security_group" "bastion" {
  name        = "bastion_host_sg"
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
  name        = "app_host_sg"
  description = "SG rules for the Expense Tracker App Host"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/26"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
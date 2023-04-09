variable "key_name" {
  description = "Name of the SSH keypair to use in AWS."
}

variable "aws_region" {
  description = "AWS region to launch servers."
  default     = "us-east-1"
}

# ubuntu-trusty-14.04 (x64)
variable "aws_amis" {
  default = {
    "us-east-1" = "ami-5f709f34"
    "us-west-2" = "ami-7f675e4f"
  }
}
output "address" {
  value = aws_elb.web.dns_name
}
terraform {
  required_version = ">= 0.12"
}
resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.web.id
  allocation_id = aws_eip.example.id
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.foo.id
  route_table_id = aws_route_table.bar.id
}

resource "aws_instance" "web" {
  ami               = "ami-21f78e11"
  availability_zone = "us-west-2a"
  instance_type     = "t2.micro"
  disable_api_termination = true
  tags = {
    Name = "HelloWorld"
  }
}

resource "aws_eip" "example" {
  vpc = true
}

provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "default" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "tf_test"
  }
}

resource "aws_vpc_peering_connection" "foo" {
  peer_owner_id = var.peer_owner_id
  peer_vpc_id   = aws_vpc.bar.id
  vpc_id        = aws_vpc.foo.id
  auto_accept   = true

  tags = {
    Name = "VPC Peering between foo and bar"
  }
}

resource "aws_vpc" "foo" {
  cidr_block = "10.1.0.0/16"
}

resource "aws_vpc" "bar" {
  cidr_block = "10.2.0.0/16"
}

resource "aws_subnet" "tf_test_subnet" {
  vpc_id                  = aws_vpc.default.id
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "tf_test_subnet"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.default.id

  tags = {
    Name = "tf_test_ig"
  }
}

resource "aws_route_table" "r" {
  vpc_id = aws_vpc.default.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "aws_route_table"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.tf_test_subnet.id
  route_table_id = aws_route_table.r.id
}

# Our default security group to access
# the instances over SSH and HTTP
resource "aws_security_group" "default" {
  name        = "instance_sg"
  description = "Used in the terraform"
  vpc_id      = aws_vpc.default.id

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Our elb security group to access
# the ELB over HTTP
resource "aws_security_group" "elb" {
  name        = "elb_sg"
  description = "Used in the terraform"

  vpc_id = aws_vpc.default.id

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ensure the VPC has an Internet gateway or this step will fail
  depends_on = [aws_internet_gateway.gw]
}

resource "aws_elb" "web" {
  name = "example-elb"

  # The same availability zone as our instance
  subnets = [aws_subnet.tf_test_subnet.id]

  security_groups = [aws_security_group.elb.id]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 30
  }

  # The instance is registered automatically

  instances                   = [aws_instance.web.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
}

resource "aws_lb_cookie_stickiness_policy" "default" {
  name                     = "lbpolicy"
  load_balancer            = aws_elb.web.id
  lb_port                  = 80
  cookie_expiration_period = 600
}

resource "aws_instance" "web" {
  instance_type = "t2.micro"

  # Lookup the correct AMI based on the region
  # we specified
  ami = var.aws_amis[var.aws_region]

  # The name of our SSH keypair you've created and downloaded
  # from the AWS console.
  #
  # https://console.aws.amazon.com/ec2/v2/home?region=us-west-2#KeyPairs:
  #
  key_name = var.key_name

  # Our Security group to allow HTTP and SSH access
  vpc_security_group_ids = [aws_security_group.default.id]
  subnet_id              = aws_subnet.tf_test_subnet.id
  user_data              = file("userdata.sh")

  #Instance tags

  tags = {
    Name = "elb-example"
  }
}
key_name = "terraform-aws-provider-example"
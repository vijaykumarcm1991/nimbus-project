resource "aws_vpc" "nimbus" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "nimbus-staging-vpc"
  }
}

resource "aws_subnet" "nimbus_public" {
  vpc_id                  = aws_vpc.nimbus.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "nimbus-staging-subnet"
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "nimbus_app" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.nimbus_public.id

  tags = {
    Name = "nimbus-staging-app"
  }
}

resource "aws_dynamodb_table" "nimbus_urls" {
  name         = "nimbus-staging-urls"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "code"

  attribute {
    name = "code"
    type = "S"
  }

  tags = {
    Name = "nimbus-staging-urls"
  }
}
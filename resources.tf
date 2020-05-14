provider "aws" {
    region="${var.region}" 
}

resource "aws_vpc" "module_vpc" {
  cidr_block = "${var.vpc_cidr_block}"
}

resource "aws_subnet" "module_subnet" {
  vpc_id     = "${aws_vpc.module_vpc.id}"
  cidr_block = "${var.subnet_cidr_block}"
}

resource "aws_security_group" "all" {
  name        = "all"
  description = "Allow all inbound traffic"
  vpc_id      = "${aws_vpc.module_vpc.id}"

  ingress {
    description = "all VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh"
  }
}

resource "aws_instance" "testInstance" {
  ami           = "${var.instance_image}"
  instance_type = "t2.micro"
  count = var.instance_count
  vpc_security_group_ids = ["${aws_security_group.all.id}"]  
  associate_public_ip_address=true
  subnet_id="${aws_subnet.module_subnet.id}"
  connection {
    host        = coalesce(self.public_ip,self.private_ip)
    type        = "ssh"
    user        = "ec2-user"
    password    = ""
  }
  }
 



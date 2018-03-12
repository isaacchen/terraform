provider "aws" {
  region                  = "${var.aws_region}"
  shared_credentials_file = "${var.shared_credentials_file}"
  profile                 = "${var.aws_profile}"
}

resource "aws_key_pair" "auth" {
  key_name   = "${var.aws_keypair_name}"
  public_key = "${file(var.public_key_path)}"
}

resource "aws_vpc" "default" {
  cidr_block = "${var.ip_block}.0.0/16"
  tags {
    Name = "${var.vpc_name_tag}"
  }
}

resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"
}

resource "aws_route" "igw" {
  route_table_id         = "${aws_vpc.default.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.default.id}"
}

resource "aws_subnet" "pub1" {
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "${var.ip_block}.0.0/23"
  availability_zone       = "${var.az1}"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "pub2" {
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "${var.ip_block}.2.0/23"
  availability_zone       = "${var.az2}"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "pvt1" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.ip_block}.4.0/23"
  availability_zone = "${var.az1}"
}

resource "aws_subnet" "pvt2" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "${var.ip_block}.6.0/23"
  availability_zone = "${var.az2}"
}

resource "aws_eip" "nat1" {
  vpc = true
}

resource "aws_eip" "nat2" {
  vpc = true
}

resource "aws_nat_gateway" "nat1" {
  subnet_id     = "${aws_subnet.pub1.id}"
  allocation_id = "${aws_eip.nat1.id}"
}

resource "aws_nat_gateway" "nat2" {
  subnet_id     = "${aws_subnet.pub2.id}"
  allocation_id = "${aws_eip.nat2.id}"
}

resource "aws_route_table" "pvt1" {
  vpc_id = "${aws_vpc.default.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.nat1.id}"
  }
}

resource "aws_route_table" "pvt2" {
  vpc_id = "${aws_vpc.default.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.nat2.id}"
  }
}

resource "aws_route_table_association" "pvt1" {
  subnet_id      = "${aws_subnet.pvt1.id}"
  route_table_id = "${aws_route_table.pvt1.id}"
}

resource "aws_route_table_association" "pvt2" {
  subnet_id      = "${aws_subnet.pvt2.id}"
  route_table_id = "${aws_route_table.pvt2.id}"
}

resource "aws_security_group" "sg_instance" {
  name        = "${var.teststr} ${var.app} instance"
  description = "${var.teststr} ${var.app} instance"
  vpc_id      = "${aws_vpc.default.id}"
  tags {
    Name = "${var.teststr} ${var.app} instance"
  }

  # SSH access from lan
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.ip_block}.0.0/16"]
  }

  # HTTP access from ELB
  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["${var.ip_block}.0.0/16"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "sg_elb" {
  name        = "${var.teststr} ${var.app} elb"
  description = "${var.teststr} ${var.app} elb"
  vpc_id      = "${aws_vpc.default.id}"
  tags {
    Name = "${var.teststr} ${var.app} elb"
  }

  # HTTP access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${var.office1}", "${var.office2}", "${var.home1}"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "default" {
  name               = "${var.teststr}-${var.app}"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "default" {
  name = "${var.teststr}-app"
  role = "${aws_iam_role.default.id}"
}

resource "aws_instance" "app" {
  # use RI that meets requirement
  instance_type          = "c3.large"
  ami                    = "${lookup(var.aws_amis, var.aws_region)}"
  key_name               = "${aws_key_pair.auth.id}"
  iam_instance_profile   = "${aws_iam_instance_profile.default.name}"
  vpc_security_group_ids = ["${aws_security_group.sg_instance.id}"]
  subnet_id              = "${aws_subnet.pvt1.id}"
  user_data              = "${file("user_data.yml")}"
  connection {
    user = "ec2-user"
  }
  tags {
    Name = "${var.teststr} ${var.app}"
  }
  ebs_block_device {
    device_name           = "/dev/xvdf"
    volume_type           = "gp2"
    volume_size           = "16"
    delete_on_termination = true
  }
  depends_on = ["aws_route_table.pvt1"]
}

resource "aws_elb" "app" {
  name            = "${var.teststr}-${var.app}"
  subnets         = ["${aws_subnet.pub1.id}"]
  security_groups = ["${aws_security_group.sg_elb.id}"]
  instances       = ["${aws_instance.app.id}"]

  listener {
    instance_port     = 9000
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    target              = "HTTP:9000/sonar/"
    interval            = 10
  }
}
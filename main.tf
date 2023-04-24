terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  profile = "default"
}

locals {
  ami           = "ami-09a0dac4253cfa03f" # Amazon Linux 2
  instance_type = "t3.micro"              # free-tier instance type
  bucket_name   = "arena-infra-test-brian-bucket"
}


# Create a key pair with the public key file specified
resource "aws_key_pair" "ssh_key" {
  key_name   = "ssh_key"
  public_key = file(var.ssh_public_key_filename)
}

# Setup user data via cloud-init, that will:
# 1. Install Docker, amazon-cloudwatch-agent, and setup the required Docker user groups (one-time)
# 2. Create a `web` directory in the ec2-user home folder, and write a simple index.html file (one-time)
# 3. Start a Docker container with Nginx that mounts the `web` directory from (2) (on every boot)
locals {
  cloud_config = <<-END
	#cloud-config
	${jsonencode({
  write_files = [
    {
      # files in /var/lib/cloud/scripts/per-once/ are executed once
      path        = "/var/lib/cloud/scripts/per-once/initial-setup.sh"
      permissions = "0755"
      owner       = "root:root"
      content     = <<-EOF
					#!/bin/bash
					yum update -y
					yum install -y docker amazon-cloudwatch-agent
					usermod -a -G docker ec2-user
					newgrp docker
					systemctl enable docker.service
					systemctl start docker.service
					mkdir -p /home/ec2-user/web
					echo "Hello World" > /home/ec2-user/web/index.html
          sudo yum install awscli
          touch refresh.sh
          echo '#!/bin/bash' >> refresh.sh
          echo 'aws s3 cp s3:bucket-demo909/index.html /home/ec2-user/web/index.html' >> refresh.sh
          chmod +x refresh.sh
      
          echo '* * * * * refresh.sh' >> /etc/crontab
          
          

				EOF
        // At the above I tried to run cronjob . But I couldn't complete it on time.
    },
    {
      # files in /var/lib/cloud/scripts/per-boot/ are executed on every boot
      path        = "/var/lib/cloud/scripts/per-boot/start-nginx.sh"
      permissions = "0755"
      owner       = "root:root"
      content     = <<-EOF
					#!/bin/bash
					/home/ec2-user/refresh-index.sh
					docker pull nginx
					docker run -d -p 80:80 \
						-v /home/ec2-user/web:/usr/share/nginx/html \
						nginx
				EOF
    }
  ]
})}
  END
}

data "cloudinit_config" "server" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/cloud-config"
    filename     = "cloud-config.yaml"
    content      = local.cloud_config
  }
}

# Create an EC2 instance with the key pair and user data configured above
resource "aws_instance" "server" {
  ami                         = local.ami
  instance_type               = local.instance_type
  key_name                    = aws_key_pair.ssh_key.key_name
  user_data_replace_on_change = false
  subnet_id                   = aws_subnet.private_subnets[0].id
  user_data                   = data.cloudinit_config.server.rendered
  vpc_security_group_ids = [aws_security_group.web_server.id]
//  iam_instance_profile = aws_iam_instance_profile.ec2_profile.arn
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = false
  

  depends_on = [
    aws_iam_role.s3_access, 
    aws_iam_role_policy_attachment.s3_access_attachment,
    aws_security_group.web_server
  ]

  tags = {
    Name = "server"
  }
}
resource "aws_iam_instance_profile" "ec2_profile" {
 // name = "ec2_profile"
  role = "${aws_iam_role.s3_access.name}"
}

resource "aws_security_group" "web_server" {
  name_prefix = "web_server"
  vpc_id      = aws_vpc.vpc.id
  
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_lb" "load_balancer" {
  name               = "aws-lb"
  internal           = false
  load_balancer_type = "application"

  subnets = [
    aws_subnet.public_subnets[0].id,
    aws_subnet.public_subnets[1].id,
  ]

  security_groups = [
    aws_security_group.lb.id
  ]

  tags = {
    Name = "aws-lb"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.load_balancer.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.http.arn
  }
}

resource "aws_lb_target_group" "http" {
  name_prefix      = "aws-tg"
  port             = 80
  protocol         = "HTTP"
  target_type      = "instance"
  vpc_id           = aws_vpc.vpc.id

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
    path                = "/"
  }
}

resource "aws_s3_bucket" "bucket" {
  bucket = "bucket-demo909"
  
  acl = "private"
  
  tags = {
    Name = "My Bucket"
  }
}

resource "aws_iam_role" "s3_access" {
  name = "s3_access"

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

resource "aws_iam_role_policy_attachment" "s3_access_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = aws_iam_role.s3_access.name
}
resource "aws_security_group" "lb" {
  name_prefix = "example-lb-"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
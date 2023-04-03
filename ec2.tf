provider "aws" {
  region = "us-east-1"
}

# Create a security group that allows access only from the specified IP address
resource "aws_security_group" "allow_ip" {
  name_prefix = "allow_ip"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["91.231.246.50/32"]
  }
}

# Create an Elastic IP address
resource "aws_eip" "ip" {
  vpc = true
}

# Launch an EC2 instance with Apache web server and assign the Elastic IP address to it
resource "aws_instance" "web_server" {
  ami           = "ami-0c94855ba95c71c99" # Ubuntu Server 20.04 LTS
  instance_type = "t2.micro"
  user_data     = <<-EOF
                  #!/bin/bash
                  sudo apt-get update
                  sudo apt-get -y install apache2
                  EOF

  # Associate the Elastic IP address with the instance
  network_interface {
    associate_public_ip_address = true
    security_group_ids = [aws_security_group.allow_ip.id]
  }
  tags = {
    Name = "web_server"
  }
}

# Create an NLB to route traffic to the EC2 instance
resource "aws_lb" "web_lb" {
  name               = "web_lb"
  load_balancer_type = "network"

  subnet_mapping {
    subnet_id = "<subnet-id>"
  }
}

# Create a target group for the EC2 instance
resource "aws_lb_target_group" "web_target_group" {
  name_prefix      = "web_target_group"
  port             = 80
  protocol         = "TCP"
  target_type      = "instance"
  vpc_id           = "<vpc-id>"
}

# Associate the EC2 instance with the target group
resource "aws_lb_target_group_attachment" "web_attachment" {
  target_group_arn = aws_lb_target_group.web_target_group.arn
  target_id        = aws_instance.web_server.id
  port             = 80
}

# Configure the NLB to route traffic to the target group
resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_lb.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.web_target_group.arn
    type             = "forward"
  }
}

# Output the public IP address of the EC2 instance and the DNS name of the NLB
output "public_ip" {
  value = aws_instance.web_server.public_ip
}

output "nlb_dns_name" {
  value = aws_lb.web_lb.dns_name
}


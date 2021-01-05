provider "aws" {
  region = "us-east-1"
}

#Configuring backend for tfstate file
terraform {
  backend "s3" {
      bucket = "kaos-terraform-state"
      key = "modules/services/webservers-cluster/terraform.tfstate"
      region = "us-east-1"

      dynamodb_table = "kaos-terraform-state-lock"
      encrypt = true
  }
}

#Getting default VPC from AWS
data "aws_vpc" "default" {
  default = true
}

#Configuring local variables (can't be changed or overriden outside of this module)
locals {
  http_port = 8082
  any_port = 0
  any_protocol = "-1"
  tcp_protocol = "tcp"
  all_ips = ["0.0.0.0/0"]  
  ami_id = "ami-00ddb0e5626798373" #Ubuntu 20.04 Free Tier Eligable
}

#Geting subnets inside default VPC
data "aws_subnet_ids" "example" {
  vpc_id = data.aws_vpc.default.id
}

#Getting RDS databse endpoint info from remote state file
data "terraform_remote_state" "db" {
  backend = "s3"

  config = {
    bucket = var.db_remote_state_bucket
    key = var.db_remote_state_key
    region = "us-east-1"
  }
}

#Preparing template file for user_data script for EC2 instances
data "template_file" "user_data" {
  template = file("${path.module}/user-data.sh")

  vars = {
    server_port = local.http_port
    db_address  = data.terraform_remote_state.db.outputs.rds_address
    db_port     = data.terraform_remote_state.db.outputs.rds_port
  }
}

#Configuring SG for EC2 instances to accept tcp:8081 connections
resource "aws_security_group" "httpin8081" {
  name        = "${var.cluster_name}-httpin8081"
  description = "value"
}

resource "aws_security_group_rule" "allow_8081_in" {
  type = "ingress"
  security_group_id = aws_security_group.httpin8081.id
  
  cidr_blocks       = local.all_ips
  description       = "value"
  from_port         = local.http_port
  ipv6_cidr_blocks  = []
  prefix_list_ids   = []
  protocol          = local.tcp_protocol
  self              = false
  to_port           = local.http_port  
  }
  

#Configuring SG for Load Balancer to allow tcp:8081
resource "aws_security_group" "alb" {
  name = "${var.cluster_name}-alb"
}

resource "aws_security_group_rule" "alb_allow_8081_in" {
  type = "ingress"
  security_group_id = aws_security_group.alb.id


  cidr_blocks       = local.all_ips
  description       = "value"
  from_port         = local.http_port
  ipv6_cidr_blocks  = []
  prefix_list_ids   = []
  protocol          = local.tcp_protocol
  self              = false
  to_port           = local.http_port
}

resource "aws_security_group_rule" "alb_allow_all_out" {
  type = "egress" 
  security_group_id = aws_security_group.alb.id

  cidr_blocks       = local.all_ips
  description       = "value"
  from_port         = local.any_port
  ipv6_cidr_blocks  = []
  prefix_list_ids   = []
  protocol          = local.any_protocol
  self              = false
  to_port           = local.any_port
} 
  

#Configuring launch configuration for ASG
resource "aws_launch_configuration" "test123" {
  image_id               = local.ami_id
  instance_type          = var.instance_type
  security_groups        = [aws_security_group.httpin8081.id]

  user_data = data.template_file.user_data.rendered

  lifecycle {
    create_before_destroy = true
  }
  }

#Configring ASG
resource "aws_autoscaling_group" "test123" {
  launch_configuration  = aws_launch_configuration.test123.name
  vpc_zone_identifier   = data.aws_subnet_ids.example.ids # using all default subnets from default VPC

  target_group_arns = [aws_lb_target_group.asg-target.arn]
  health_check_type = "ELB"
  min_size = var.min_size
  max_size = var.max_size

  tag {
    key                 = "Name"
    value               = "${var.cluster_name}-example"
    propagate_at_launch = true
  }
  }
  
#Configuring App Load Balancer
resource "aws_lb" "example" {
  name                = "${var.cluster_name}-lb"
  load_balancer_type  = "application"
  subnets             = data.aws_subnet_ids.example.ids 
  security_groups     = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn   = aws_lb.example.arn
  port                = local.http_port
  protocol            = "HTTP"

  #By default, return 404 code

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

#Configuring target group for ALB
resource "aws_lb_target_group" "asg-target" {
  name      = "${var.cluster_name}-target"
  port      = local.http_port
  protocol  = "HTTP"
  vpc_id    = data.aws_vpc.default.id
  
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2

  } 
}

#Configuring listener rules for ALB
resource "aws_lb_listener_rule" "asg-listener" {
  listener_arn = aws_lb_listener.http.arn
  priority = 100

  condition {
    path_pattern {
      values = [ "*" ]
    }
  }
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.asg-target.arn
  }
}
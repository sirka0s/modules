output "alb_dns_name" {
  value = aws_lb.example.dns_name
  description = "DNS for LB"
}

output "asg_name" {
  value = aws_autoscaling_group.test123.name
  description = "The name of Auto Scaling Group"
}
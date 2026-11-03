output "alb_dns_name" {
  description = "Nom DNS de l'ALB - point d'entree du site"
  value       = aws_lb.web.dns_name
}

output "asg_name" {
  description = "Nom du groupe d'auto-scaling web"
  value       = aws_autoscaling_group.web.name
}

output "monitoring_public_ip" {
  description = "IP publique de l'instance monitoring"
  value       = module.monitoring.public_ip
}

output "target_group_arn" {
  description = "ARN du target group web"
  value       = aws_lb_target_group.web.arn
}

output "vpc_id" {
  description = "ID du VPC de l'environnement"
  value       = module.vpc.vpc_id
}

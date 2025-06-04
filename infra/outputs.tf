output "alb_dns_name" {
  description = "DNS do Application Load Balancer."
  value       = aws_lb.main_alb.dns_name
}

output "alb_http_listener_arn" {
  description = "ARN do listener HTTP do ALB."
  value       = aws_lb_listener.http_listener.arn
}

# output "alb_https_listener_arn" {
#   description = "ARN do listener HTTPS do ALB (se criado)."
#   value       = length(aws_lb_listener.https_listener) > 0 ? aws_lb_listener.https_listener[0].arn : "N/A"
# }

output "ecs_cluster_name" {
  description = "Nome do cluster ECS."
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "Nome do serviço ECS."
  value       = aws_ecs_service.app_service.name
}

output "s3_bucket_id" {
  description = "ID (nome) do bucket S3 criado."
  value       = aws_s3_bucket.app_bucket.id
}

output "s3_bucket_arn" {
  description = "ARN do bucket S3 criado."
  value       = aws_s3_bucket.app_bucket.arn
}

output "app_cloudwatch_log_group_name" {
  description = "Nome do CloudWatch Log Group para a aplicação."
  value       = aws_cloudwatch_log_group.app_logs.name
}
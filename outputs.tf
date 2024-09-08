# ./alb.tf
output "alb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = concat(aws_lb.this.*.dns_name, [""])[0]
}

output "alb_sg" {
  description = "The security group of the load balancer"
  value       = concat(aws_security_group.this.*.id, [""])[0]
}

output "alb_arn" {
  description = "The arn of the load balancer"
  value       = concat(aws_lb.this.*.id, [""])[0]
}

output "alb_zoneid" {
  description = "The canonical hosted zone ID of the load balancer (to be used in a Route 53 Alias record)."
  value       = concat(aws_lb.this.*.zone_id, [""])[0]
}





# ./ecs_cluster.tf
output "ecs_cluster_id" {
  description = "The Id of the ECS Cluster"
  value       = concat(aws_ecs_cluster.this.*.id, [""])[0]
}

# ./ecs_app.tf
output "ecs_task_sg" {
  description = "The security group of the ecs task."
  value       = concat(aws_security_group.ecs_tasks.*.id, [""])[0]
}
output "ecs_service_discovery_dns" {
  description = "The dns name of the service discovery."
  value       = "${var.name}.${var.name}.local"
}
output "cloudwatch_log_group" {
  description = "All outputs from `aws_cloudwatch_log_group.this`"
  value       = aws_cloudwatch_log_group.this
}
output "cloudwatch_log_group_name" {
  description = "The name of the cloudwatch log group that will contain the app logs for the ecs task."
  value       = concat(aws_cloudwatch_log_group.this.*.name, [""])[0]
}

# ./cicd.tf
/*
output "codepipeline_url" {
  description = "The codepipeline URL"
  value       = "https://console.aws.amazon.com/codepipeline/home?region=${var.region}#/view/${join("", aws_codepipeline.pipeline.*.id)}"
}
*/

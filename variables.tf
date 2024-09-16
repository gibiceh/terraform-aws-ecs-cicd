# common
variable "name" {
  description = "The name to be used for all resources."
  type        = string
}

variable "aws_region" {
  description = "The region to be used for all resources."
  type        = string
}

variable "aws_account_id" {
  description = "The account id to be used for all resources."
  type        = string
}

variable "tags" {
  description = "This is to help add tags to the provisioned AWS resources."
  type        = map(any)
}

# ./cicd.tf
variable "create_cicd" {
  description = "Choice to create a cicd pipeline."
  type        = bool
  default     = true
}

variable "create_cicd_notification_pipeline" {
  description = "Choice to create notification pipeline."
  type        = bool
  default     = false
}

variable "cloudfront_distribution_id" {
  description = "The distribution ID for Cloudfront."
  type        = string
  default     = ""
}

variable "cloudfront_invalidation_path" {
  description = "The validation path to be used to clear the cache in cloudfront cdn."
  type        = string
  default     = "/*"
}

variable "invalidate_cdn_cache" {
  description = "Choice to invalidate cdn cache."
  type        = bool
  default     = false
}

variable "invalidate_cdn_cache_lambda" {
  description = "The name of the lambda function that will be invoked to invalidate the cache of the cloudfront distribution."
  type        = string
  default     = ""
}

variable "notification_topic_arn" {
  description = "The arn of the sns topic to send event notifications."
  type        = string
  default     = ""
}

variable "codepipeline_source_owner" {
  description = "The owner of the source code."
  type        = string
  default     = ""
}

variable "codepipeline_source_provider" {
  description = "The provider of the source code."
  type        = string
  default     = "CodeStarSourceConnection"
}

variable "codepipeline_source_git_repo_owner" {
  description = "The owner of the git repository."
  type        = string
  default     = "AWS"
}

variable "codepipeline_source_git_repo_name" {
  description = "The name of the git repository."
  type        = string
  default     = ""
}

variable "codepipeline_source_git_repo_branch" {
  description = "The branch of the git repository."
  type        = string
  default     = ""
}

variable "codepipeline_source_codestar_connection_arn" {
  description = "The arn of the codestar connection to the git platform source."
  type        = string
  default     = ""
  sensitive   = true
}

variable "codebuild_compute_type" {
  description = "The compute type for the codebuild project."
  type        = string
  default     = "BUILD_GENERAL1_SMALL"
}

variable "codebuild_image" {
  description = "The image for the codebuild project."
  type        = string
  default     = "aws/codebuild/standard:5.0"
}

variable "codebuild_type" {
  description = "The type for the codebuild project."
  type        = string
  default     = "LINUX_CONTAINER"
}

variable "container_repo_arn" {
  description = "The arn of the ecr repository."
  type        = string
  default     = ""
}

variable "alb_listener_arn" {
  description = "The arn of the alb listener."
  type        = string
  default     = ""
}

variable "ecs_app_target_group_arns" {
  description = "The arn of the target group."
  type        = list(string)
  default     = []
}

variable "ecs_app_target_group_names" {
  description = "The name of the target group."
  type        = list(string)
  default     = []
}

variable "container_image" {
  description = "The image to be used for the container."
  type        = string
  default     = ""
}

variable "ecs_task_definition_arn" {
  description = "The arn of the ecs task definition."
  type        = string
  default     = ""
}

variable "ecs_family" {
  description = "The family of the ecs task definition."
  type        = string
  default     = ""
}

variable "ecs_task_subnet_id" {
  description = "The subnet id to be used for the ecs task."
  type        = string
  default     = ""
}

variable "ecs_task_security_group_id" {
  description = "The security group id to be used for the ecs task."
  type        = string
  default     = ""
}

variable "ecs_service_name" {
  description = "The name of the ECS service."
  type        = string
  default     = ""
}

variable "ecs_container_port" {
  description = "The port the container listens on."
  type        = number
  default     = 3000
}

variable "ecs_container_name" {
  description = "The name of the container."
  type        = string
  default     = ""
}




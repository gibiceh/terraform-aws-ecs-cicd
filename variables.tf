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
  default     = ""
}

variable "codepipeline_source_git_owner" {
  description = "The owner of the git repository."
  type        = string
  default     = ""
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

variable "codepipeline_source_git_oauth_token" {
  description = "The oauth token for the git repository."
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

variable "codebuild_buildspec" {
  description = "The buildspec file for the codebuild project."
  type        = any
}

variable "container_repo_arn" {
  description = "The arn of the ecr repository."
  type        = string
  default     = ""
}





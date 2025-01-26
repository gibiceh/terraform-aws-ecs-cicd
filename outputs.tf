

# ./cicd.tf
output "s3_bucket_artifact_id" {
  description = "The S3 bucket ID to store artifacts for the application"
  value       = join("", aws_s3_bucket.artifact_bucket.*.id) != null ? aws_s3_bucket.artifact_bucket.id : var.byo_s3_bucket_artifact_id
}

/*
output "codepipeline_url" {
  description = "The codepipeline URL"
  value       = "https://console.aws.amazon.com/codepipeline/home?region=${var.region}#/view/${join("", aws_codepipeline.pipeline.*.id)}"
}
*/

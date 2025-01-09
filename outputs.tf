

# ./cicd.tf
output "s3_bucket_id" {
  description = "The S3 bucket ID"
  value       = aws_s3_bucket.artifact_bucket.id
}

/*
output "codepipeline_url" {
  description = "The codepipeline URL"
  value       = "https://console.aws.amazon.com/codepipeline/home?region=${var.region}#/view/${join("", aws_codepipeline.pipeline.*.id)}"
}
*/

#: Locals ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

#: DRY module implementations:::::::::::::::::::::::::::::::::::::::::::::::::::

#: Resources :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#: -----------------------------------------------------------------------------
#: S3 Bucket
#: Provision to store artifacts needed for the ci/cd pipeline
#: examples:  env files
#: -----------------------------------------------------------------------------

resource "aws_s3_bucket" "artifact_bucket" {

  bucket = var.name

  tags = var.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_sse_artifact_bucket" {
  bucket = join("", aws_s3_bucket.artifact_bucket.*.bucket)

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

#: -----------------------------------------------------------------------------
#: Code Build
#: -----------------------------------------------------------------------------
data "aws_iam_policy_document" "assume_by_codebuild" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codebuild" {
  name               = "${var.name}-codebuild"
  assume_role_policy = data.aws_iam_policy_document.assume_by_codebuild.json
  path               = "/"
}

data "aws_iam_policy_document" "codebuild" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "ecr:GetAuthorizationToken"
    ]
    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject"
    ]
    effect    = "Allow"
    resources = ["${aws_s3_bucket.artifact_bucket.arn}/*"]
  }

  statement {
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload"
    ]
    effect    = "Allow"
    resources = ["${var.container_repo_arn}"]
  }

  statement {
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecs:Describe*"
    ]
    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability"
    ]
    effect    = "Allow"
    resources = ["${var.container_repo_arn}"]
  }
}

resource "aws_iam_role_policy_attachment" "codebuild" {
  role       = aws_iam_role.codebuild.name
  policy_arn = data.aws_iam_policy_document.codebuild.json
}

resource "aws_codebuild_project" "codebuild" {

  name         = "${var.name}-codebuild"
  service_role = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type                = var.codebuild_compute_type
    image                       = var.codebuild_image
    type                        = var.codebuild_type
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "S3_BUCKET_NAME"
      value = aws_s3_bucket.artifact_bucket.id
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = var.codebuild_buildspec
  }
}


#: --------------------------------------------------------------------------------------------------------------------
#: Code Pipeline
#: --------------------------------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "assume_by_codepipeline" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "codepipeline" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:GetBucketVersioning"
    ]
    effect    = "Allow"
    resources = ["${aws_s3_bucket.artifact_bucket.arn}/*"]
  }

  statement {
    actions = [
      "codebuild:StartBuild",
      "codebuild:BatchGetBuilds",
      "cloudformation:*",
      "codestar-connections:*",
      "iam:PassRole"
    ]
    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    actions = [
      "ecs:*",
      "codedeploy:GetDeployment",
      "codedeploy:GetApplication",
      "codedeploy:CreateDeployment",
      "codedeploy:GetApplicationRevision",
      "codedeploy:GetDeploymentConfig",
      "codedeploy:RegisterApplicationRevision"
    ]
    effect    = "Allow"
    resources = ["*"]
  }

  statement {
    actions = [
      "codedeploy:*"
    ]
    effect    = "Allow"
    resources = ["*"]
  }

  /*
  statement {
    actions = [
      "lambda:InvokeFunction"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:lambda:${var.aws_region}:${var.aws_account_id}:function:${var.invalidate_cdn_cache_lambda}"
    ]
  }
*/
}

resource "aws_iam_role" "codepipeline" {
  name               = "${var.name}-codepipeline"
  assume_role_policy = data.aws_iam_policy_document.assume_by_codepipeline.json
  path               = "/"
}

resource "aws_iam_role_policy_attachment" "codepipeline" {
  role       = aws_iam_role.codepipeline.name
  policy_arn = data.aws_iam_policy_document.codepipeline.json
}

/*
#: --------------------------------------------------------------------------------------------------------------------
#: Code Deploy
#: --------------------------------------------------------------------------------------------------------------------

data "aws_iam_policy_document" "assume_by_codedeploy" {
  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codedeploy" {
  name               = "${var.name}-codedeploy"
  assume_role_policy = data.aws_iam_policy_document.assume_by_codedeploy.json
  path               = "/"
}

data "aws_iam_policy_document" "codedeploy" {

  statement {
    sid    = "AllowLoadBalancingAndECSModifications"
    effect = "Allow"

    actions = [
      "autoscaling:*",
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "ecs:CreateTaskSet",
      "ecs:DeleteTaskSet",
      "ecs:DescribeServices",
      "ecs:DescribeClusters",
      "ecs:UpdateServicePrimaryTaskSet",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:ModifyRule",
      "lambda:InvokeFunction",
      "cloudwatch:DescribeAlarms",
      "sns:Publish",
      "s3:GetObject",
      "s3:GetObjectMetadata",
      "s3:GetObjectVersion",
      "iam:PassRole"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy_attachment" "codedeploy" {
  role       = aws_iam_role.codedeploy.name
  policy_arn = aws_iam_policy.codedeploy.arn
}

resource "aws_codedeploy_app" "this" {
  compute_platform = "ECS"
  name             = "${var.name}-codedeploy"
}

resource "aws_codedeploy_deployment_group" "this" {

  app_name               = join("", aws_codedeploy_app.this.*.name)
  deployment_group_name  = "${var.name}-deploy-group"
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  service_role_arn       = join("", aws_iam_role.codedeploy.*.arn)

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 1
    }
  }

  ecs_service {
    cluster_name = "${var.tags["project"]}-${var.tags["env"]}"
    service_name = join("", aws_ecs_service.lb.*.name)
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = ["${var.alb_listener_arn}"]
      }

      target_group {
        name = var.ecs_app_target_group_names[0]
      }

      target_group {
        name = var.ecs_app_target_group_names[1]
      }
    }
  }

}
*/

#: --------------------------------------------------------------------------------------------------------------------
#: CodePipeline
#: --------------------------------------------------------------------------------------------------------------------

resource "aws_codepipeline" "pipeline" {
  name     = "${var.name}-codepipeline"
  role_arn = aws_iam_role.codepipeline.arn
  artifact_store {
    location = aws_s3_bucket.artifact_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = var.codepipeline_source_owner
      provider         = var.codepipeline_source_provider
      version          = "1"
      output_artifacts = ["code"]

      configuration = {
        Owner                = var.codepipeline_source_git_owner
        Repo                 = var.codepipeline_source_git_repo_name
        Branch               = var.codepipeline_source_git_repo_branch
        OAuthToken           = var.codepipeline_source_git_oauth_token
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      version          = "1"
      provider         = "CodeBuild"
      input_artifacts  = ["code"]
      output_artifacts = ["BuildOutput"]
      run_order        = 1
      configuration = {
        ProjectName = aws_codebuild_project.codebuild.id
      }
    }
  }

  /*
  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      input_artifacts = ["BuildOutput"]
      version         = "1"

      configuration = {
        ApplicationName                = join("", aws_codedeploy_app.this.*.name)
        DeploymentGroupName            = "${var.name}-deploy-group"
        TaskDefinitionTemplateArtifact = "BuildOutput"
        TaskDefinitionTemplatePath     = "taskdef.json"
        AppSpecTemplateArtifact        = "BuildOutput"
        AppSpecTemplatePath            = "appspec.yml"
      }
    }
  }
*/
  /*
  stage {
    name = "Deploy"
    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      version         = "1"
      provider        = "ECS"
      run_order       = 1
      input_artifacts = ["BuildOutput"]
      configuration = {
        ClusterName       = var.ecs_cluster
        ServiceName       = "${var.name}-service"
        FileName          = "imagedefinitions.json"
        DeploymentTimeout = "15"
      }
    }
  }

  */
}



############################
/*
resource "aws_codestarnotifications_notification_rule" "aws_codestarnotifications_notification_rule_codepipeline" {
  count       = var.create_cicd_notification_pipeline ? 1 : 0
  detail_type = "BASIC"
  event_type_ids = [
    "codepipeline-pipeline-pipeline-execution-failed",
    "codepipeline-pipeline-pipeline-execution-canceled",
    "codepipeline-pipeline-pipeline-execution-started",
    "codepipeline-pipeline-pipeline-execution-resumed",
    "codepipeline-pipeline-pipeline-execution-succeeded",
    "codepipeline-pipeline-pipeline-execution-superseded"
  ]
  name     = "${var.name}-notifications-rule-codepipeline"
  resource = join("", aws_codepipeline.pipeline.*.arn)

  target {
    address = var.notification_topic_arn
  }
}
*/



# Outputs ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
## Please include in ./outputs.tf





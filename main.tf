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
#: CodeBuild
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

resource "aws_iam_policy" "codebuild" {
  name   = "${var.name}-codebuild"
  path   = "/"
  policy = data.aws_iam_policy_document.codebuild.json
}

resource "aws_iam_role" "codebuild" {
  name               = "${var.name}-codebuild"
  assume_role_policy = data.aws_iam_policy_document.assume_by_codebuild.json
  path               = "/"
}

resource "aws_iam_role_policy_attachment" "codebuild" {
  role       = aws_iam_role.codebuild.name
  policy_arn = aws_iam_policy.codebuild.arn
}

resource "aws_codebuild_project" "codebuild" {

  name         = var.name
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
      name  = "REPOSITORY_URI"
      value = var.container_image
    }
    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }
    environment_variable {
      name  = "CONTAINER_NAME"
      value = var.ecs_container_name
    }
    environment_variable {
      name  = "S3_BUCKET_NAME"
      value = aws_s3_bucket.artifact_bucket.id
    }
    environment_variable {
      name  = "SERVICE_PORT"
      value = var.ecs_container_port
    }
    environment_variable {
      name  = "TASK_DEFINITION"
      value = var.ecs_task_definition_arn
    }
    environment_variable {
      name  = "TASK_DEFINITION_FAMILY"
      value = var.ecs_family
    }
    environment_variable {
      name  = "TASK_SUBNET_ID"
      value = var.ecs_task_subnet_id
    }
    environment_variable {
      name  = "TASK_SECURITY_GROUP"
      value = var.ecs_task_security_group_id
    }
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = <<BUILDSPEC
version: 0.2
phases:
  install:
    commands:
      - apt-get update -y
      - apt-get install -y jq
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
      - aws ecr get-login-password | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
      - COMMIT_HASH=$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - IMAGE_TAG=$${COMMIT_HASH:=latest}         
  build:
    commands:
      - echo Build started on `date`
      - echo Retrieve environment variables needed for the yarn build
      - aws --region $AWS_DEFAULT_REGION s3 cp s3://$S3_BUCKET_NAME/envfile.env .env || true
      - echo Building the Docker image...
      - docker build -t $REPOSITORY_URI:latest .
      - docker tag $REPOSITORY_URI:latest $REPOSITORY_URI:$IMAGE_TAG
  post_build:
    commands:
      - echo Build completed on `date`
      - echo Pushing the Docker image...
      - docker push $REPOSITORY_URI:latest
      - docker push $REPOSITORY_URI:$IMAGE_TAG
      - printf '[{"name":"%s","imageUri":"%s"}]' $CONTAINER_NAME $REPOSITORY_URI:$IMAGE_TAG > imagedefinitions.json
      - aws --region $AWS_DEFAULT_REGION ecs describe-task-definition --task-definition camcorner | jq '.taskDefinition' > taskdef.json
      - envsubst < iac/camcorner/appspec_template.yml > appspec.yml
artifacts:
    files:
      - imagedefinitions.json
      - appspec.yml
      - taskdef.json
BUILDSPEC
  }
}


#: --------------------------------------------------------------------------------------------------------------------
#: CodeDeploy
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

resource "aws_iam_policy" "codedeploy" {
  name   = "${var.name}-codedeploy"
  path   = "/"
  policy = data.aws_iam_policy_document.codedeploy.json
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
  name             = var.name
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
    cluster_name = "${var.name}-cluster"
    service_name = "${var.name}-service" #join("", aws_ecs_service.lb.*.name)
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


#: --------------------------------------------------------------------------------------------------------------------
#: CodePipeline
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

  statement {
    actions = [
      "lambda:InvokeFunction"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:lambda:${var.aws_region}:${var.aws_account_id}:function:${var.invalidate_cdn_cache_lambda}"
    ]
  }

}

resource "aws_iam_policy" "codepipeline" {
  name   = "${var.name}-codepipeline"
  path   = "/"
  policy = data.aws_iam_policy_document.codepipeline.json
}

resource "aws_iam_role" "codepipeline" {
  name               = "${var.name}-codepipeline"
  assume_role_policy = data.aws_iam_policy_document.assume_by_codepipeline.json
  path               = "/"
}

resource "aws_iam_role_policy_attachment" "codepipeline" {
  role       = aws_iam_role.codepipeline.name
  policy_arn = aws_iam_policy.codepipeline.arn
}

resource "aws_codepipeline" "pipeline" {
  name     = var.name
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
        ConnectionArn        = var.codepipeline_source_codestar_connection_arn
        FullRepositoryId     = format("%s/%s", var.codepipeline_source_git_repo_owner, var.codepipeline_source_git_repo_name)
        BranchName           = var.codepipeline_source_git_repo_branch
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
        ApplicationName                = aws_codedeploy_app.this.name
        DeploymentGroupName            = "${var.name}-deploy-group"
        TaskDefinitionTemplateArtifact = "BuildOutput"
        TaskDefinitionTemplatePath     = "taskdef.json"
        AppSpecTemplateArtifact        = "BuildOutput"
        AppSpecTemplatePath            = "appspec.yml"
      }
    }
  }
}

#: Outputs :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#: Please include in ./outputs.tf





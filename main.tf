# Arquivo principal do Terraform para criação de uma aplicação web com Auto Scaling Group, CodeDeploy e CodePipeline

terraform { 
    required_providers {
      aws = {
        source  = "hashicorp/aws"
        version = ">= 5.43.0"
      }
    }
    required_version = ">= 1.7.5"
}

provider "aws" {
  region                  = "us-east-1" 
}

# Criação da IAM Role para o AWS CodeDeploy
resource "aws_iam_role" "codedeploy_role" {
  name = "coodesh-codedeploy-role"
  assume_role_policy = jsonencode({
    Version: "2012-10-17",
    Statement: [
      {
        Effect: "Allow",
        Principal: {
          Service: "codedeploy.amazonaws.com"
        },
        Action: "sts:AssumeRole"
      }
    ]
  })
}

# Anexa a política de serviço AWSCodeDeployRole à role do CodeDeploy
resource "aws_iam_role_policy_attachment" "codedeploy_role_policy_attachment" {
  role       = aws_iam_role.codedeploy_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

# Criação da IAM Role para instâncias EC2 se comunicarem com o AWS CodeDeploy
resource "aws_iam_role" "codedeploy_ec2_role" {
  name = "coodesh-ec2-codedeploy-role"
  assume_role_policy = jsonencode({
    Version: "2012-10-17",
    Statement: [
      {
        Effect: "Allow",
        Principal: {
          Service: "ec2.amazonaws.com"
        },
        Action: "sts:AssumeRole"
      }
    ]
  })
}

# Política para permitir que instâncias EC2 acessem artefatos no S3
resource "aws_iam_policy" "codedeploy_ec2_to_s3_policy" {
  name        = "coodesh-ec2-codedeploy-to-S3-policy"
  description = "Permite que instâncias EC2 acessem artefatos no S3"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:Get*", "s3:List*"]
        Resource = "*" 
      }
    ]
  })
}

# Anexa a política de acesso ao S3 à role do EC2
resource "aws_iam_role_policy_attachment" "attach_codedeploy_ec2_to_s3_policy" {
  role       = aws_iam_role.codedeploy_ec2_role.name
  policy_arn = aws_iam_policy.codedeploy_ec2_to_s3_policy.arn
}

# Anexa a política básica de instância gerenciada pela AWS (para log, etc.)
resource "aws_iam_role_policy_attachment" "attach_ssminstancecore_policy" {
  role       = aws_iam_role.codedeploy_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Criação de uma IAM Instance Profile para EC2 usar as roles definidas
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "coodesh-ec2-instance-profile"
  role = aws_iam_role.codedeploy_ec2_role.name
}
# Criação da IAM Role para o CodePipeline
resource "aws_iam_policy" "codestar_connection_policy" {
  name        = "coodesh-codestar-connection-policy"
  description = "Política que permite ações necessárias para a conexão do CodeStar e ações do CodeDeploy para o projeto Coodesh"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "codestar-connections:UseConnection",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:RegisterApplicationRevision",
          "codedeploy:GetApplicationRevision"
        ],
        Resource = "*"
      }
    ]
  })
}


# Anexa a política para conexão com CodeStar
resource "aws_iam_role_policy_attachment" "attach_codestar_connection_policy" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.codestar_connection_policy.arn
}

# Define a política do CodeBuild para permitir a assunção de role
data "aws_iam_policy_document" "codebuild_policy" {
  statement {
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

# Cria a IAM Role para o CodeBuild
resource "aws_iam_role" "codebuild_role" {
  name               = "coodesh-codebuild-role"
  assume_role_policy = data.aws_iam_policy_document.codebuild_policy.json
}

# Política do CodeBuild para escrita no CloudWatch e S3
resource "aws_iam_policy" "codebuild_policy" {
  name        = "coodesh-codebuild-policy"
  description = "Permite que o CodeBuild escreva no CloudWatch e acesse o S3"
  policy      = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "cloudwatch:*",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
          "logs:DescribeLogStreams",
          "s3:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# Anexa a política ao CodeBuild Role
resource "aws_iam_role_policy_attachment" "attach_codebuild_policy" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.codebuild_policy.arn
}

# Cria a IAM Role para o CodePipeline
resource "aws_iam_role" "codepipeline_role" {
  name = "coodesh-codepipeline-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { "Service": "codepipeline.amazonaws.com" },
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# Política para execução do CodePipeline
resource "aws_iam_policy" "codepipeline_execution_policy" {
  name        = "coodesh-codepipeline-execution-policy"
  description = "Permite que o CodePipeline inicie builds e deployments"
  policy      = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "codebuild:StartBuild",
          "codebuild:BatchGetBuilds",
          "codedeploy:CreateDeployment",
          "codedeploy:GetDeploymentConfig",
          "s3:Get*",
          "s3:List*",
          "s3:PutObject",
          "cloudwatch:*"
        ],
        Resource = "*"
      }
    ]
  })
}

# Anexa a política de execução do CodePipeline à role
resource "aws_s3_bucket" "build_artifacts_bucket" {
  bucket = "coodesh-build-artifacts"
}

# Habilita o versionamento do bucket
resource "aws_s3_bucket_versioning" "build_artifacts_bucket_versioning" {
  bucket = aws_s3_bucket.build_artifacts_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Cria um bucket S3 para armazenar os artefatos do CodePipeline
resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "coodesh-codepipeline-artifacts"
}


# Habilita o versionamento do bucket
resource "aws_s3_bucket_versioning" "codepipeline_bucket_versioning" {
  bucket = aws_s3_bucket.codepipeline_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Security Group para a aplicação
resource "aws_security_group" "application_sg" {
  name        = "coodesh-application-sg"
  description = "Security group para a aplicacao web Coodesh"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Permite HTTP"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ip]
    description = "Permite SSH"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Busca a AMI mais recente do Ubuntu Server 20.04 LTS
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# Template de Lançamento para o Auto Scaling Group utilizando a AMI do Ubuntu 20.04
resource "aws_launch_template" "launch_template" {
  name_prefix   = "coodesh-launch-template-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  # Anexe o IAM Instance Profile criado anteriormente
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance_profile.name
  }

  # Configure o Security Group
  vpc_security_group_ids = [aws_security_group.application_sg.id]

  # Usa o script de inicialização
  user_data = base64encode(file("${path.module}/app/scripts/init.sh"))
}



# Auto Scaling Group configurado para utilizar o template de lançamento
resource "aws_autoscaling_group" "autoscaling_group" {
  name                      = "coodesh-autoscaling-group"
  max_size                  = 2
  min_size                  = 1
  desired_capacity          = 1
  health_check_grace_period = 300
  health_check_type         = "EC2"
  force_delete              = true
  launch_template {
    id      = aws_launch_template.launch_template.id
    version = "$Latest"
  }

  # Especifique as zonas de disponibilidade
  availability_zones = ["us-east-1a", "us-east-1b"]
}

# Aplicativo CodeDeploy
resource "aws_codedeploy_app" "codedeploy_app" {
  name              = "coodesh-codedeploy-app"
  compute_platform  = "Server"
}

# Grupo de Deployment do CodeDeploy
resource "aws_codedeploy_deployment_group" "deployment_group" {
  app_name               = aws_codedeploy_app.codedeploy_app.name
  deployment_group_name  = "coodesh-codedeploy-group"
  service_role_arn       = aws_iam_role.codedeploy_role.arn

  # Configuração de deployment
  deployment_config_name = "CodeDeployDefault.OneAtATime"
  
  autoscaling_groups    = [aws_autoscaling_group.autoscaling_group.name]

  # Configuração de rollback automático em caso de falha
  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
}


# Projeto CodeBuild
resource "aws_codebuild_project" "codebuild_project" {
  name          = "coodesh-codebuild-project"
  description   = "Build project para a aplicação Coodesh"
  build_timeout = "5" # Em minutos
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:4.0"
    type                        = "LINUX_CONTAINER"
  }

  source {
    type            = "CODEPIPELINE"
    buildspec       = "buildspec.yml"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "coodesh-codebuild-logs"
      stream_name = "coodesh-codebuild-stream"
    }
  }
}

# Conexão do CodeStar com o GitHub
resource "aws_codestarconnections_connection" "codestar_connection_example" {
  name       = "coodesh-codestar-connection"
  provider_type = "GitHub"
}


# Pipeline de integração e entrega contínua
resource "aws_codepipeline" "codepipeline" {
  name     = "coodesh-codepipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"
  }

# Definição das etapas do pipeline
  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.codestar_connection_example.arn
        FullRepositoryId = var.github_repository
        BranchName       = var.github_branch
      }
    }
  }

# Etapa de Build
  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.codebuild_project.name
      }
    }
  }

# Etapa de Deploy
  stage {
    name = "Deploy"
    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      input_artifacts = ["build_output"]
      version         = "1"
        configuration = {
        ApplicationName     = aws_codedeploy_app.codedeploy_app.name
        DeploymentGroupName = aws_codedeploy_deployment_group.deployment_group.deployment_group_name
        }
    }
  }
}


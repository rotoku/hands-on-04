data "aws_caller_identity" "current" {}
data "aws_iam_policy_document" "ecs_task_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# --- IAM Role para Execução da Tarefa ECS (ECS Task Execution Role) ---
# Necessária para o agente ECS puxar a imagem do ECR e enviar logs para o CloudWatch.
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${var.project_name}-ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role_policy.json

  tags = {
    Name      = "${var.project_name}-ecs-task-execution-role"
    Terraform = "true"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# --- IAM Role para a Tarefa ECS (ECS Task Role) ---
# Permissões que a sua aplicação dentro do contêiner terá.
resource "aws_iam_role" "ecs_task_role" {
  name               = "${var.project_name}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role_policy.json

  tags = {
    Name      = "${var.project_name}-ecs-task-role"
    Terraform = "true"
  }
}

# Política para acesso ao S3
data "aws_iam_policy_document" "s3_access_policy_doc" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
      "s3:DeleteObject"
      # Adicione outras ações S3 conforme necessário
    ]
    resources = [
      aws_s3_bucket.app_bucket.arn,
      "${aws_s3_bucket.app_bucket.arn}/*", # Acesso aos objetos dentro do bucket
    ]
  }
}

resource "aws_iam_policy" "s3_access_policy" {
  name        = "${var.project_name}-s3-access-policy"
  description = "Política para permitir que as tarefas ECS acessem o bucket S3."
  policy      = data.aws_iam_policy_document.s3_access_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_s3_access_attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}
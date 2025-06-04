# --- S3 Bucket ---
resource "aws_s3_bucket" "app_bucket" {
  # Nomes de bucket S3 devem ser globalmente únicos.
  bucket = "${lower(var.project_name)}-${data.aws_caller_identity.current.account_id}-${var.s3_bucket_name_suffix}"

  # Acl obsoleto, use aws_s3_bucket_acl se realmente necessário, mas prefira políticas de bucket e IAM.
  # acl    = "private" # Recomenda-se usar políticas de bucket e IAM em vez de ACLs.

  tags = {
    Name        = "${var.project_name}-app-bucket"
    Environment = "production" # Ou conforme seu ambiente
    Terraform   = "true"
  }
}

# Bloquear todo o acesso público ao bucket S3 (recomendado)
resource "aws_s3_bucket_public_access_block" "app_bucket_public_access_block" {
  bucket = aws_s3_bucket.app_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# --- ECS Cluster ---
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled" # Habilita Container Insights para monitoramento
  }

  tags = {
    Name      = "${var.project_name}-cluster"
    Terraform = "true"
  }
}

# --- CloudWatch Log Group para a Aplicação ---
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/ecs/${var.project_name}-app"
  retention_in_days = 7 # Configure a retenção conforme necessário

  tags = {
    Name      = "${var.project_name}-app-logs"
    Terraform = "true"
  }
}

# --- ECS Task Definition ---
resource "aws_ecs_task_definition" "app_task" {
  family                   = "${var.project_name}-app-task"
  network_mode             = "awsvpc" # Necessário para Fargate
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.fargate_cpu
  memory                   = var.fargate_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn # Role para puxar imagem e logs
  task_role_arn            = aws_iam_role.ecs_task_role.arn           # Role para a aplicação (acesso S3)

  container_definitions = jsonencode([
    {
      name      = "${var.project_name}-app-container"
      image     = var.app_image_url # Sua imagem Docker no ECR
      cpu       = var.fargate_cpu
      memory    = var.fargate_memory
      essential = true
      portMappings = [
        {
          containerPort = var.app_port
          hostPort      = var.app_port # No Fargate, hostPort e containerPort geralmente são os mesmos
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs" # Prefixo para os streams de log
        }
      }
      environment = [ # Adicione variáveis de ambiente para sua aplicação aqui
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "prod" # ou o perfil que você usa
        },
        {
          name  = "S3_BUCKET_NAME" # Exemplo: se sua app precisa do nome do bucket
          value = aws_s3_bucket.app_bucket.bucket
        }
        # Adicione outras variáveis de ambiente aqui
      ]
      # healthCheck = { # Opcional, mas recomendado
      #   command     = ["CMD-SHELL", "curl -f http://localhost:${var.app_port}/actuator/health || exit 1"]
      #   interval    = 30
      #   timeout     = 5
      #   retries     = 3
      #   startPeriod = 60 # Tempo para o container iniciar antes de começar os health checks
      # }
    }
  ])

  tags = {
    Name      = "${var.project_name}-app-task-def"
    Terraform = "true"
  }
}

# --- Application Load Balancer (ALB) ---
resource "aws_lb" "main_alb" {
  name               = "${var.project_name}-alb"
  internal           = false # Externo
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id # ALB em subnets públicas

  enable_deletion_protection = false # Mude para true em produção

  tags = {
    Name      = "${var.project_name}-alb"
    Terraform = "true"
  }
}

# --- Target Group para o ALB ---
resource "aws_lb_target_group" "app_tg" {
  name        = "${var.project_name}-app-tg"
  port        = var.app_port
  protocol    = "HTTP" # Tráfego do ALB para o Fargate é HTTP
  vpc_id      = aws_vpc.main.id
  target_type = "ip" # Necessário para Fargate

  health_check {
    enabled             = true
    interval            = 30
    path                = "/actuator/health" # Ajuste para o health check da sua app Spring Boot
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200-299" # Status code para considerar saudável
  }

  tags = {
    Name      = "${var.project_name}-app-tg"
    Terraform = "true"
  }
}

# --- Listener HTTP no ALB (redireciona para HTTPS ou serve HTTP) ---
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.main_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }

  # Se você tiver um certificado SSL e quiser redirecionar HTTP para HTTPS:
  # default_action {
  #   type = "redirect"
  #   redirect {
  #     port        = "443"
  #     protocol    = "HTTPS"
  #     status_code = "HTTP_301"
  #   }
  # }
}

# --- Listener HTTPS no ALB (Opcional, mas recomendado para produção) ---
# Para usar HTTPS, você precisará de um certificado SSL no AWS Certificate Manager (ACM)
# variable "acm_certificate_arn" {
#   description = "ARN do certificado SSL do ACM para o ALB."
#   type        = string
#   default     = "" # Ex: arn:aws:acm:us-east-1:123456789012:certificate/your-certificate-id
# }
#
# resource "aws_lb_listener" "https_listener" {
#   count = var.acm_certificate_arn != "" ? 1 : 0 # Cria apenas se o ARN do certificado for fornecido
#
#   load_balancer_arn = aws_lb.main_alb.arn
#   port              = 443
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-2016-08" # Escolha uma política de SSL
#   certificate_arn   = var.acm_certificate_arn
#
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.app_tg.arn
#   }
# }

# --- ECS Service (Fargate) ---
resource "aws_ecs_service" "app_service" {
  name            = "${var.project_name}-app-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app_task.arn
  desired_count   = var.desired_task_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = aws_subnet.private[*].id # Tarefas Fargate em subnets privadas
    security_groups = [aws_security_group.fargate_task_sg.id]
    # assign_public_ip = false # Fargate em subnets privadas não devem ter IP público diretamente
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_tg.arn
    container_name   = "${var.project_name}-app-container" # Nome do container na task definition
    container_port   = var.app_port                        # Porta do container
  }

  # Para garantir que o ALB esteja pronto antes de associar o serviço
  depends_on = [aws_lb_listener.http_listener] # Ou aws_lb_listener.https_listener[0] se usar HTTPS

  # Opcional: Configurações para deploy (rolling update, blue/green)
  deployment_controller {
    type = "ECS" # Padrão é rolling update
  }

  # Aguarda a estabilização do serviço durante o 'apply' e 'destroy'
  wait_for_steady_state = true

  tags = {
    Name      = "${var.project_name}-app-service"
    Terraform = "true"
  }
}
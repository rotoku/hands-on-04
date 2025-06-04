# --- Security Group para o Application Load Balancer ---
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "Permite tráfego HTTP/HTTPS para o ALB a partir do CIDR especificado."
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP do CIDR permitido"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_ip # Restrição de IP aqui!
  }

  ingress {
    description = "HTTPS do CIDR permitido"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_ip # Restrição de IP aqui!
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Permite todo o tráfego de saída
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "${var.project_name}-alb-sg"
    Terraform = "true"
  }
}

# --- Security Group para as Tarefas Fargate ---
resource "aws_security_group" "fargate_task_sg" {
  name        = "${var.project_name}-fargate-task-sg"
  description = "Permite tráfego do ALB para as tarefas Fargate."
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Tráfego da aplicação vindo do ALB"
    from_port       = var.app_port # Porta da aplicação
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id] # Apenas do ALB
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Permite todo o tráfego de saída (para S3, ECR, etc.)
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "${var.project_name}-fargate-task-sg"
    Terraform = "true"
  }
}
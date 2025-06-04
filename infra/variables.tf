variable "aws_region" {
  description = "Região AWS para criar os recursos."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome base para os recursos do projeto."
  type        = string
  default     = "meu-app-fargate"
}

variable "vpc_cidr_block" {
  description = "Bloco CIDR para a VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Lista de blocos CIDR para as subnets públicas."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Lista de blocos CIDR para as subnets privadas."
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "allowed_cidr_ip" {
  description = "Bloco CIDR IP permitido para acessar o ALB."
  type        = list(string)
  # Exemplo: permita acesso do seu IP ou de uma VPN específica
  default = ["0.0.0.0/0"] # ATENÇÃO: Mude isso para seu CIDR específico!
}

variable "app_image_url" {
  description = "URL da imagem Docker da aplicação no ECR (ex: ACCOUNT_ID.dkr.ecr.REGION.amazonaws.com/meu-app:latest)."
  type        = string
  # Exemplo: "123456789012.dkr.ecr.us-east-1.amazonaws.com/meu-app-fargate:latest"
  # Certifique-se que esta imagem existe no ECR.
}

variable "app_port" {
  description = "Porta que a aplicação escuta dentro do contêiner."
  type        = number
  default     = 8080
}

variable "fargate_cpu" {
  description = "CPU para a tarefa Fargate (em unidades de CPU)."
  type        = number
  default     = 256 # 0.25 vCPU
}

variable "fargate_memory" {
  description = "Memória para a tarefa Fargate (em MiB)."
  type        = number
  default     = 512 # 0.5 GB
}

variable "desired_task_count" {
  description = "Número desejado de tarefas Fargate em execução."
  type        = number
  default     = 1
}

variable "s3_bucket_name_suffix" {
  description = "Sufixo para o nome do bucket S3 (será prefixado com o nome do projeto e ID da conta para unicidade)."
  type        = string
  default     = "dados-app"
}
# --- VPC ---
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name      = "${var.project_name}-vpc"
    Terraform = "true"
  }
}

# --- Subnets Públicas ---
resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)] # Distribui entre AZs

  map_public_ip_on_launch = true # Para o NAT Gateway e instâncias que precisam de IP público

  tags = {
    Name      = "${var.project_name}-public-subnet-${count.index + 1}"
    Terraform = "true"
  }
}

# --- Subnets Privadas ---
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]

  tags = {
    Name      = "${var.project_name}-private-subnet-${count.index + 1}"
    Terraform = "true"
  }
}

# --- Internet Gateway ---
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name      = "${var.project_name}-igw"
    Terraform = "true"
  }
}

# --- Rota para Internet nas Subnets Públicas ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name      = "${var.project_name}-public-rt"
    Terraform = "true"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- Elastic IP para NAT Gateway ---
resource "aws_eip" "nat" {
  domain = "vpc" # Alterado de 'vpc = true' para o novo atributo 'domain'
  tags = {
    Name      = "${var.project_name}-nat-eip"
    Terraform = "true"
  }
}

# --- NAT Gateway (para permitir que as tarefas Fargate em subnets privadas acessem a internet/ECR) ---
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id # Coloque o NAT Gateway em uma subnet pública

  tags = {
    Name      = "${var.project_name}-nat-gw"
    Terraform = "true"
  }

  depends_on = [aws_internet_gateway.gw]
}

# --- Rota para NAT Gateway nas Subnets Privadas ---
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name      = "${var.project_name}-private-rt"
    Terraform = "true"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# --- Data source para obter AZs disponíveis ---
data "aws_availability_zones" "available" {}
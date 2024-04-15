# Arquivo: variables.tf

variable "aws_region" {
  description = "A região da AWS onde os recursos serão criados"
  default     = "us-east-1"
}

variable "instance_type" {
  description = "Tipo de instância EC2"
  default     = "t2.micro"
}

variable "application_name" {
  description = "Nome da aplicação para o CodeDeploy e outros recursos"
  default     = "coodesh-application"
}

variable "github_repository" {
  description = "Repositório GitHub na forma 'usuario/repositorio (URL COMPLETO)'"
  default     = "https://github.com/gutierrezx7/coodesh-test.git"
}

variable "github_branch" {
  description = "Branch do repositório GitHub a ser utilizado"
  default     = "main"
}

variable "allowed_ip" {
  description = "Endereço IP permitido para acessar a instância"
  type        = string
  default     = "0.0.0.0/0"
}

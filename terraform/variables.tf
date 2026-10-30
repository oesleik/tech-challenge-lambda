variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "name_prefix" {
  type        = string
  default     = "tech-challenge"
  description = "Prefixo dos nomes. O dashboard do New Relic (infra-k8s) procura a função por \"<prefixo>-autenticacao\"."
}

variable "ssm_prefix" {
  type        = string
  default     = "/tech-challenge"
  description = "Prefixo dos parâmetros SSM (contrato entre repositórios)."
}

variable "jwt_secret" {
  type        = string
  default     = null
  sensitive   = true
  description = "Mesmo JWT_SECRET do PHP, para assinar o token (via TF_VAR_jwt_secret)."

  validation {
    condition     = var.jwt_secret == null || length(coalesce(var.jwt_secret, "")) >= 32
    error_message = "jwt_secret precisa ter ao menos 32 bytes (exigência do HS256 no lcobucci/jwt)."
  }
}

variable "jwt_issuer" {
  type        = string
  default     = "tech-challenge-api"
  description = "Mesmo JWT_ISSUER do PHP."
}

variable "jwt_ttl" {
  type        = number
  default     = 3600
  description = "Validade do token em segundos (JWT_TTL)."
}

variable "lambda_db_username" {
  type        = string
  default     = "autenticacao"
  description = "Usuário MySQL somente leitura (criado pelo job rds-user-setup da app)."
}

variable "lambda_db_password" {
  type        = string
  default     = null
  sensitive   = true
  description = "Senha do usuário MySQL da Lambda (via TF_VAR_lambda_db_password). Fica no state e na configuração da função."
}

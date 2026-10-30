# Lambda de autenticação: valida o CPF/CNPJ, confirma que o cliente existe no RDS e emite o
# JWT aceito pelas rotas protegidas do PHP. Acessada só via API Gateway (POST /autenticacao).

# Empacota build/ (src + package.json + node_modules de produção). O workflow de deploy
# monta essa pasta antes do plan; localmente: ver README.md.
data "archive_file" "autenticacao" {
  type        = "zip"
  source_dir  = "${path.module}/../build"
  output_path = "${path.module}/.terraform/build/autenticacao.zip"
  excludes    = ["package-lock.json", "node_modules/@types", "node_modules/undici-types"]
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "autenticacao" {
  name               = "${var.name_prefix}-autenticacao"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "autenticacao_logs" {
  role       = aws_iam_role.autenticacao.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Criar/remover as ENIs nas sub-redes privadas (vpc_config).
resource "aws_iam_role_policy_attachment" "autenticacao_vpc" {
  role       = aws_iam_role.autenticacao.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Criado antes da função para controlar a retenção (senão a Lambda cria sem expiração).
resource "aws_cloudwatch_log_group" "autenticacao" {
  name              = "/aws/lambda/${var.name_prefix}-autenticacao"
  retention_in_days = 7
}

resource "aws_lambda_function" "autenticacao" {
  function_name    = "${var.name_prefix}-autenticacao"
  role             = aws_iam_role.autenticacao.arn
  runtime          = "nodejs24.x"
  handler          = "src/index.handler"
  filename         = data.archive_file.autenticacao.output_path
  source_code_hash = data.archive_file.autenticacao.output_base64sha256
  architectures    = ["arm64"]
  memory_size      = 128
  # Cold start na VPC + handshake TLS com o RDS passam fácil dos 3s.
  timeout = 10

  vpc_config {
    subnet_ids         = local.private_subnet_ids
    security_group_ids = [aws_security_group.autenticacao.id]
  }

  environment {
    variables = {
      # Mesmas variáveis/valores do PHP (tech-chalange: charts/tech-challenge/values.yaml),
      # senão o token é rejeitado.
      JWT_SECRET = var.jwt_secret
      JWT_ISSUER = var.jwt_issuer
      JWT_TTL    = tostring(var.jwt_ttl)

      # Usuário somente leitura criado pelo job rds-user-setup do Helm (tech-chalange).
      DB_HOST     = data.aws_ssm_parameter.db_address.insecure_value
      DB_PORT     = data.aws_ssm_parameter.db_port.insecure_value
      DB_DATABASE = data.aws_ssm_parameter.db_name.insecure_value
      DB_USERNAME = var.lambda_db_username
      DB_PASSWORD = var.lambda_db_password
    }
  }

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.autenticacao.name
  }

  lifecycle {
    precondition {
      condition     = var.jwt_secret != null
      error_message = "Defina jwt_secret (TF_VAR_jwt_secret) com o mesmo JWT_SECRET usado pelo PHP."
    }

    precondition {
      condition     = var.lambda_db_password != null
      error_message = "Defina lambda_db_password (TF_VAR_lambda_db_password) com o mesmo LAMBDA_DB_PASSWORD do job rds-user-setup."
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.autenticacao_logs,
    aws_iam_role_policy_attachment.autenticacao_vpc,
  ]
}

# Logs no New Relic pelo Firehose do infra-k8s, se ele publicou o pipeline.
resource "aws_cloudwatch_log_subscription_filter" "newrelic" {
  count           = local.newrelic_logs_enabled ? 1 : 0
  name            = "${var.name_prefix}-newrelic"
  log_group_name  = aws_cloudwatch_log_group.autenticacao.name
  filter_pattern  = ""
  destination_arn = local.observability["firehose_arn"]
  role_arn        = local.observability["logs_role_arn"]
}

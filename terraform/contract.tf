# Entrada: parâmetros do tech-challenge-infra-k8s (rede, API Gateway, logs) e do
# tech-challenge-infra-db (banco). Se algum não existir, o plan falha aqui (o workflow de
# deploy checa antes, com mensagem melhor).

data "aws_ssm_parameter" "vpc_id" {
  name = "${var.ssm_prefix}/network/vpc_id"
}

data "aws_ssm_parameter" "private_subnet_ids" {
  name = "${var.ssm_prefix}/network/private_subnet_ids"
}

data "aws_ssm_parameter" "apigw_api_id" {
  name = "${var.ssm_prefix}/apigw/api_id"
}

data "aws_ssm_parameter" "apigw_execution_arn" {
  name = "${var.ssm_prefix}/apigw/execution_arn"
}

data "aws_ssm_parameter" "apigw_invoke_url" {
  name = "${var.ssm_prefix}/apigw/invoke_url"
}

data "aws_ssm_parameter" "db_address" {
  name = "${var.ssm_prefix}/db/address"
}

data "aws_ssm_parameter" "db_port" {
  name = "${var.ssm_prefix}/db/port"
}

data "aws_ssm_parameter" "db_name" {
  name = "${var.ssm_prefix}/db/name"
}

data "aws_ssm_parameter" "db_security_group_id" {
  name = "${var.ssm_prefix}/db/security_group_id"
}

# Opcional: só existe com o New Relic ligado no infra-k8s. Por caminho, para vir vazio
# (sem erro) quando não existe.
data "aws_ssm_parameters_by_path" "observability" {
  path = "${var.ssm_prefix}/observability"
}

locals {
  private_subnet_ids = split(",", data.aws_ssm_parameter.private_subnet_ids.insecure_value)

  observability = zipmap(
    [for name in data.aws_ssm_parameters_by_path.observability.names : trimprefix(name, "${var.ssm_prefix}/observability/")],
    nonsensitive(data.aws_ssm_parameters_by_path.observability.values)
  )
  newrelic_logs_enabled = alltrue([
    for key in ["firehose_arn", "logs_role_arn"] : contains(keys(local.observability), key)
  ])
}

# Saída: marca que a Lambda está de pé. O destroy do infra-db e do infra-k8s se recusa a
# rodar enquanto existir algo em lambda/ (a regra no SG do RDS travaria o destroy do SG).
resource "aws_ssm_parameter" "function_name" {
  name  = "${var.ssm_prefix}/lambda/autenticacao_function_name"
  type  = "String"
  value = aws_lambda_function.autenticacao.function_name
}

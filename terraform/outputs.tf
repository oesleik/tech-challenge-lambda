output "function_name" {
  value = aws_lambda_function.autenticacao.function_name
}

output "autenticacao_url" {
  value       = "${trimsuffix(data.aws_ssm_parameter.apigw_invoke_url.insecure_value, "/")}/autenticacao"
  description = "POST com {\"cpf_cnpj\": \"...\"}."
}

output "newrelic_logs_enabled" {
  value       = local.newrelic_logs_enabled
  description = "Se o log group foi ligado ao Firehose do New Relic."
}

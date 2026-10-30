# A API, o stage e a rota $default (para o PHP) são do infra-k8s. Aqui só a rota da Lambda:
# a rota específica tem precedência sobre o $default.

resource "aws_apigatewayv2_integration" "autenticacao" {
  api_id                 = data.aws_ssm_parameter.apigw_api_id.insecure_value
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.autenticacao.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "autenticacao" {
  api_id    = data.aws_ssm_parameter.apigw_api_id.insecure_value
  route_key = "POST /autenticacao"
  target    = "integrations/${aws_apigatewayv2_integration.autenticacao.id}"
}

resource "aws_lambda_permission" "autenticacao_apigw" {
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.autenticacao.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${data.aws_ssm_parameter.apigw_execution_arn.insecure_value}/*/*/autenticacao"
}

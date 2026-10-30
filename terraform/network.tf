# Sem regras de entrada; a saída é só para o MySQL. Sem NAT na sub-rede privada,
# a Lambda não alcança a internet (nem precisa: o JWT_SECRET e a senha vêm por env var).
resource "aws_security_group" "autenticacao" {
  name        = "${var.name_prefix}-autenticacao"
  description = "Lambda de autenticacao"
  vpc_id      = data.aws_ssm_parameter.vpc_id.insecure_value

  tags = {
    Name = "${var.name_prefix}-autenticacao"
  }
}

resource "aws_vpc_security_group_egress_rule" "autenticacao_to_rds" {
  security_group_id            = aws_security_group.autenticacao.id
  description                  = "Lambda para o MySQL do RDS"
  referenced_security_group_id = data.aws_ssm_parameter.db_security_group_id.insecure_value
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
}

# A regra fica no SG do RDS (infra-db), mas é deste repositório: quem sobe depois cria o
# acesso. Por isso o destroy do infra-db exige que a Lambda tenha saído antes.
resource "aws_vpc_security_group_ingress_rule" "rds_from_autenticacao" {
  security_group_id            = data.aws_ssm_parameter.db_security_group_id.insecure_value
  description                  = "MySQL a partir da Lambda de autenticacao"
  referenced_security_group_id = aws_security_group.autenticacao.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
}

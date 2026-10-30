# Configuração parcial: bucket, key, região e tabela de lock vêm por -backend-config
# (workflow de deploy/destroy). Na validação do CI: terraform init -backend=false.
terraform {
  backend "s3" {}
}

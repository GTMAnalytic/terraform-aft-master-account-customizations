data "aws_ssm_parameter" "ct_audit_account_id" {
  name = "/aft/account/audit/account-id"
}

data "aws_ssm_parameter" "ct_primary_region" {
  name = "/aft/config/ct-management-region"
}

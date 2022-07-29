resource "aws_accessanalyzer_analyzer" "access_analyzer" {
  analyzer_name = "AccessAnalyzer-${data.aws_ssm_parameter.ct_primary_region}-${data.aws_ssm_parameter.ct_audit_account_id.value}"
  type = "ORGANIZATION"
}
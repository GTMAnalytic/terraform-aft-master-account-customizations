data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "master_account_bucket" {
  bucket = "aft-master-account-${data.aws_caller_identity.current.account_id}" 
}

resource "aws_s3_bucket_acl" "master_account_bucket_acl" {
  bucket = aws_s3_bucket.master_account_bucket.id
  acl = "private"
}

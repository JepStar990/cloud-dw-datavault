output "raw_vault_bucket_name" {
  value = aws_s3_bucket.raw_vault.bucket
}

output "raw_vault_bucket_arn" {
  value = aws_s3_bucket.raw_vault.arn
}

output "ec2_public_ip" {
  value = aws_instance.dw_node.public_ip
}

output "ec2_public_dns" {
  value = aws_instance.dw_node.public_dns
}

output "resolved_al2023_ami" {
  value = data.aws_ssm_parameter.al2023_ami.value
  sensitive  = true
}


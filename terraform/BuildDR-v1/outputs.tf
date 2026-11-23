# ── Outputs ───────────────────────────────────────────────────────────────────
output "alb_url" {
  description = "Application URL"
  value       = "http://${aws_lb.alb.dns_name}"
}

output "aurora_endpoint" {
  description = "Aurora cluster endpoint"
  value       = aws_rds_cluster.aurora_cluster.endpoint
}

output "s3_bucket_name" {
  description = "S3 bucket for product images"
  value       = aws_s3_bucket.image_bucket.id
}

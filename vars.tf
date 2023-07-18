variable "environment" {
  type    = string
  default = "production"
}

variable "s3_bucket_arn" {
  type    = string
  default = "arn:aws:s3:::thelatestlead"
}

variable "host" {
  type        = string
  description = "The DNS name by which this instance can be reached over the public Internet. This is required so TLS certificates can be automatically issued and renewed."
}

variable "public_key" {
  type        = string
  description = "The contents of your SSH public key, so you can SSH into the instance and run administrative commands."
}

variable "email" {
  type        = string
  description = "Your email, for certificate authorities to contact you if something goes wrong."
}

variable "tls_staging" {
  type        = bool
  default     = false
  description = "Whether to use test certificates instead of real ones. Enable this during debugging to avoid getting rate-limited by the certificate authority."
}

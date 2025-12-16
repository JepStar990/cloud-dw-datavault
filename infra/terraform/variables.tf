variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-1" # You can switch to af-south-1 if preferred
}

variable "project_name" {
  description = "Project name used for naming"
  type        = string
  default     = "cloud-dw-datavault"
}

variable "instance_type" {
  description = "EC2 instance type (free tier: t2.micro, or t3.micro where t2 not available)"
  type        = string
  default     = "t3.micro"
}

variable "ssh_key_name" {
  description = "Existing EC2 key pair name for SSH access"
  type        = string
  default     = "cloud-dw-key"
}

variable "ssh_ingress_cidr" {
  description = "CIDR for SSH ingress (restrict to your IP)"
  type        = string
   default     = "0.0.0.0/0"
}

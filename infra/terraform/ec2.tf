# Resolve the latest AL2023 x86_64 AMI via SSM public parameter
# Docs: /aws/service/ami-amazon-linux-latest/...  (returns the AMI ID)
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Security Group for the instance
resource "aws_security_group" "dw_sg" {
  name        = "${var.project_name}-sg"
  description = "Allow SSH (and all egress)"
  vpc_id      = data.aws_vpc.default.id

  # SSH - restrict in real deployments
  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [var.ssh_ingress_cidr]
    ipv6_cidr_blocks = []
  }

  egress {
    description      = "All traffic egress"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}

# Use the default VPC (Week 1 keeps networking minimal)
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# EC2 instance
resource "aws_instance" "dw_node" {
  ami                    = data.aws_ssm_parameter.al2023_ami.value
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.dw_sg.id]
  key_name               = var.ssh_key_name != "" ? var.ssh_key_name : null

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  user_data = file("${path.module}/user_data.sh")

  tags = {
    Name = "dw-free-tier"
  }
}

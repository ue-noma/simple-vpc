data "aws_ami" "windows_2022" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base*"]
  }
}

resource "aws_security_group" "aws_windows_sg" {
  name        = "my_windows_sg"
  description = "Allow incoming connections"
  vpc_id      = module.vpc.vpc_id
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow incoming RDP connections"
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow incoming RDP connections"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

# Create EC2 Instance
resource "aws_instance" "windows_server" {
  ami                         = data.aws_ami.windows_2022.id
  instance_type               = "t2.medium"
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.aws_windows_sg.id]
  source_dest_check           = false
  key_name                    = aws_key_pair.key_pair.key_name
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.windows_instalce.name

  # root disk
  root_block_device {
    volume_size           = "30"
    volume_type           = "gp2"
    delete_on_termination = true
    encrypted             = true
  }

  tags = {
    Name        = "my_windows_server_vm"
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_iam_instance_profile" "windows_instalce" {
  name = "my_windows_server_profile"
  role = aws_iam_role.windows_instalce.name
}

resource "aws_iam_role" "windows_instalce" {
  name                = "windows_instance_role"
  path                = "/"
  assume_role_policy  = data.aws_iam_policy_document.instance_assume_role_policy.json
  managed_policy_arns = [
    data.aws_iam_policy.ssm_managed_core.arn,
    aws_iam_policy.windows_instalce.arn
  ]
}

data "aws_iam_policy" "ssm_managed_core" {
  name = "AmazonSSMManagedInstanceCore"
}

resource "aws_iam_policy" "windows_instalce" {
  name   = "my-windows-server"
  path   = "/"
  policy = data.aws_iam_policy_document.windows_instalce.json
}

data "aws_iam_policy_document" "windows_instalce" {
  statement {
    sid = "1"

    actions = [
      "cloudwatch:*",
    ]

    resources = [
      "*",
    ]
    # resources = [
    #   aws_instance.windows_server.arn,
    #   data.aws_ssm_document.cloudwatch_manage_agent.arn
    # ]
  }
}

data "aws_iam_policy_document" "instance_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
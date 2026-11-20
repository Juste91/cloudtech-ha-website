data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_security_group" "web" {
  name        = "cloudtech-ha-web"
  description = "Allow HTTP from the load balancer"
  vpc_id      = aws_subnet.public_b.vpc_id

  ingress {
    description     = "HTTP from the load balancer"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "HTTPS for package downloads and Systems Manager"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "web" {
  name = "CloudTech-HA-Web-SSM-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.web.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "web" {
  name = "CloudTech-HA-Web-Profile"
  role = aws_iam_role.web.name
}

resource "aws_launch_template" "web" {
  name_prefix   = "cloudtech-ha-web-"
  image_id      = data.aws_ssm_parameter.al2023.value
  instance_type = "t3.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.web.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.web.id]
  }

  metadata_options {
    http_tokens = "required"
  }

  user_data = base64encode(<<-SCRIPT
    #!/bin/bash
    set -e
    dnf install -y httpd
    printf '<h1>Welcome to CloudTech</h1><p>Served by %s</p>\n' "$(hostname)" > /var/www/html/index.html
    systemctl enable --now httpd
  SCRIPT
  )
}

resource "aws_autoscaling_group" "web" {
  name                      = "cloudtech-ha-web"
  min_size                  = 2
  desired_capacity          = 2
  max_size                  = 2
  health_check_type         = "ELB"
  health_check_grace_period = 300
  target_group_arns         = [aws_lb_target_group.web.arn]

  vpc_zone_identifier = [
    var.existing_public_subnet_id,
    aws_subnet.public_b.id,
  ]

  launch_template {
    id      = aws_launch_template.web.id
    version = tostring(aws_launch_template.web.latest_version)
  }

  tag {
    key                 = "Name"
    value               = "CloudTech-HA-Web"
    propagate_at_launch = true
  }

  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy_attachment.ssm,
  ]
}

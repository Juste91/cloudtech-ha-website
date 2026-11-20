resource "aws_security_group" "alb" {
  name        = "cloudtech-ha-alb"
  description = "Allow web traffic to the CloudTech load balancer"
  vpc_id      = aws_subnet.public_b.vpc_id

  ingress {
    description = "Public HTTP for the lab"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP requests and health checks to the web subnets"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/24", aws_subnet.public_b.cidr_block]
  }
}

resource "aws_lb" "web" {
  name               = "cloudtech-ha-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]

  subnets = [
    var.existing_public_subnet_id,
    aws_subnet.public_b.id,
  ]

  depends_on = [aws_route_table_association.public_b]
}

resource "aws_lb_target_group" "web" {
  name        = "cloudtech-ha-web"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_subnet.public_b.vpc_id

  health_check {
    path    = "/"
    matcher = "200"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

output "website_url" {
  value = "http://${aws_lb.web.dns_name}"
}

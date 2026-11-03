data "aws_ami" "debian" {
  most_recent = true
  owners      = ["136693071363"]

  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# IP publique du poste qui execute Terraform, seulement si admin_cidr n'est pas fourni
# (la CI fournit admin_cidr : sinon l'IP du runner change a chaque run et le plan n'est jamais vide)
data "http" "my_ip" {
  count = nonsensitive(var.admin_cidr) == "" ? 1 : 0
  url   = "https://api.ipify.org"
}

locals {
  my_cidr = var.admin_cidr != "" ? var.admin_cidr : "${chomp(data.http.my_ip[0].response_body)}/32"
  name    = "novasphere-${var.environment}-${var.owner}"
}


module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "novasphere-${var.environment}"
  cidr = "10.0.0.0/16"

  azs            = ["us-east-1a", "us-east-1b"]
  public_subnets = ["10.0.1.0/24", "10.0.2.0/24"]

  enable_nat_gateway      = false
  map_public_ip_on_launch = true
}


resource "aws_security_group" "alb" {
  name        = "${local.name}-alb"
  description = "ALB public - HTTP depuis Internet"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP public"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Sortie autorisee (mises a jour, SSM)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "asg_web" {
  name        = "${local.name}-asg-web"
  description = "Instances ASG - HTTP uniquement depuis l ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "HTTP depuis l ALB uniquement"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Sortie autorisee (mises a jour, SSM)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_launch_template" "web" {
  name_prefix   = "${local.name}-"
  image_id      = data.aws_ami.debian.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.main.key_name

  vpc_security_group_ids = [aws_security_group.asg_web.id]

  iam_instance_profile {
    name = data.aws_iam_instance_profile.lab.name
  }

  # Meme script en dev et en prod : l'environnement est injecte par templatefile
  user_data = base64encode(templatefile("${path.module}/bootstrap.sh.tftpl", {
    environment = var.environment
    region      = var.aws_region
  }))

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${local.name}-asg-web"
      Role = "web"
    }
  }
}


resource "aws_lb" "web" {
  name                       = local.name
  load_balancer_type         = "application"
  subnets                    = module.vpc.public_subnets
  security_groups            = [aws_security_group.alb.id]
  drop_invalid_header_fields = true
}

resource "aws_lb_target_group" "web" {
  name     = "${local.name}-web"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    path    = "/"
    matcher = "200"
  }
}

resource "aws_lb_listener" "http" {
  #checkov:skip=CKV_AWS_2:Pas de domaine ni de certificat ACM dans le Learner Lab, HTTPS impossible
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}


resource "aws_autoscaling_group" "web" {
  name                = "${local.name}-web"
  min_size            = 2
  max_size            = 4
  desired_capacity    = 2
  vpc_zone_identifier = module.vpc.public_subnets
  target_group_arns   = [aws_lb_target_group.web.arn]
  health_check_type   = "ELB"

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${local.name}-web"
    propagate_at_launch = true
  }
}


resource "aws_ssm_parameter" "db_password" {
  name             = "/novasphere/${var.environment}/db_password"
  type             = "SecureString"
  value_wo         = var.db_password
  value_wo_version = 1
}


data "aws_iam_instance_profile" "lab" {
  name = "LabInstanceProfile"
}

resource "aws_key_pair" "main" {
  key_name   = "${local.name}-key"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

module "monitoring" {
  source        = "git::https://github.com/novasphere-eam-team/terraform-aws-ec2-server.git?ref=v1.3.0"
  name          = "${local.name}-monitoring"
  ami_id        = data.aws_ami.debian.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.main.key_name
  admin_cidr    = local.my_cidr
  open_ports    = []
  role          = "monitoring"
}

# Inventaire Ansible genere depuis les outputs : aucune IP recopiee a la main
resource "local_file" "inventory" {
  count = var.generate_inventory ? 1 : 0

  filename        = "${path.module}/../../ansible/inventory.ini"
  file_permission = "0644"
  content = templatefile("${path.module}/inventory.tftpl", {
    web_ip = aws_lb.web.dns_name
  })
}

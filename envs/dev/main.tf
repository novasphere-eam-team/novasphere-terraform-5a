# Image Debian 12 officielle la plus recente
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

# IP publique du poste qui execute Terraform (pattern my_ip, acquis Bac+4)
data "http" "my_ip" {
  url = "https://api.ipify.org"
}

locals {
  my_cidr = "${chomp(data.http.my_ip.response_body)}/32"
  name    = "novasphere-${var.environment}-${var.owner}"
}

resource "aws_key_pair" "main" {
  key_name   = "${local.name}-key"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

module "web" {
  source        = "git::https://github.com/EliasA98/terraform-aws-ec2-server.git?ref=v1.0.0"
  name          = "${local.name}-web"
  ami_id        = data.aws_ami.debian.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.main.key_name
  admin_cidr    = local.my_cidr
  open_ports    = [80]
}
module "monitoring" {
  source        = "git::https://github.com/EliasA98/terraform-aws-ec2-server.git?ref=v1.0.0"
  name          = "${local.name}-monitoring"
  ami_id        = data.aws_ami.debian.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.main.key_name
  admin_cidr    = local.my_cidr
  open_ports    = []
}
moved {
  from = aws_instance.web
  to   = module.web.aws_instance.this
}

moved {
  from = aws_security_group.web
  to   = module.web.aws_security_group.this
}

# Inventaire Ansible genere depuis les outputs : aucune IP recopiee a la main
resource "local_file" "inventory" {
  filename        = "${path.module}/../../ansible/inventory.ini"
  file_permission = "0644"
  content = templatefile("${path.module}/inventory.tftpl", {
    web_ip = module.web.public_ip
  })
}

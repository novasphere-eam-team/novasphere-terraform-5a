variable "name" {
  description = "Nom logique du serveur (web, monitoring...)"
  type        = string
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "key_name" {
  type = string
}

variable "admin_cidr" {
  description = "CIDR autorise en SSH"
  type        = string
}

variable "open_ports" {
  description = "Ports TCP ouverts a tout Internet (ex : [80])"
  type        = list(number)
  default     = []
}

variable "tags" {
  type    = map(string)
  default = {}
}

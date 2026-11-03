# Fournisseur OIDC GitHub + role CI : HORS LAB SEULEMENT (compte AWS personnel).
# Dans le Learner Lab, iam:CreateRole est refuse : la CI utilise les credentials
# de session stockes dans les secrets du depot (exigence du cahier des charges).
# Ce code documente le modele cible ; ne pas l'appliquer dans le lab.

terraform {
  required_version = ">= 1.14"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "novasphere-tfstate-eam"
    key          = "global/oidc/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:novasphere-eam-team/novasphere-terraform-5a:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "novasphere-github-actions"
  assume_role_policy = data.aws_iam_policy_document.trust.json

  tags = {
    Project = "NovaSphere"
  }
}

# Large pour le projet ecole ; a restreindre en production reelle.
resource "aws_iam_role_policy_attachment" "admin" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

output "role_arn" {
  description = "A mettre dans le secret GitHub AWS_ROLE_ARN"
  value       = aws_iam_role.github_actions.arn
}

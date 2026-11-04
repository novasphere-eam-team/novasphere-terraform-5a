# NovaSphere — infrastructure web multi-environnements sur AWS

Infrastructure web déployée par **Terraform** sur **AWS** (Learner Lab, région `us-east-1`), en
deux environnements isolés, **dev** et **prod**, livrée par **GitHub Actions**, sans aucun secret en
clair.

| Dépôt | Rôle |
|---|---|
| [novasphere-terraform-5a](https://github.com/novasphere-eam-team/novasphere-terraform-5a) | Ce dépôt : environnements, CI/CD, documentation |
| [terraform-aws-ec2-server](https://github.com/novasphere-eam-team/terraform-aws-ec2-server) | Module de l'équipe, appelé par tag (`?ref=v1.3.0`) |

**Ce qui est déployé, par environnement** : un VPC sur deux zones de disponibilité, un Application
Load Balancer, un groupe d'auto-scaling de deux instances Debian 12 qui servent une page
« NovaSphere - DEV » ou « NovaSphere - PROD », et un mot de passe applicatif stocké dans Parameter
Store, lu par les instances au démarrage.

Documentation : [ARCHITECTURE](ARCHITECTURE.md) · [SECURITE](SECURITE.md) ·
[CONTRIBUTING](CONTRIBUTING.md) · [CADRAGE](CADRAGE.md) · [RESTE_A_FAIRE](RESTE_A_FAIRE.md)

---

## Sommaire

1. [Prérequis](#1-prérequis)
2. [Récupérer le code](#2-récupérer-le-code)
3. [Credentials AWS](#3-credentials-aws)
4. [Backend du state](#4-backend-du-state)
5. [Variables](#5-variables)
6. [Déployer par la CI (voie normale)](#6-déployer-par-la-ci-voie-normale)
7. [Déployer en local (test sur son propre lab)](#7-déployer-en-local-test-sur-son-propre-lab)
8. [Vérifier](#8-vérifier)
9. [Détruire](#9-détruire)
10. [Structure du dépôt](#10-structure-du-dépôt)

---

## 1. Prérequis

| Outil | Version | Vérification |
|---|---|---|
| Git | 2.30 ou plus | `git --version` |
| Terraform | 1.14 ou plus | `terraform version` |
| AWS CLI | 2.x | `aws --version` |

Il faut aussi :

- un compte GitHub membre de l'organisation `novasphere-eam-team` ;
- une session **AWS Academy Learner Lab** démarrée ;
- une paire de clés SSH (la clé publique est déposée sur les instances) :

```bash
ssh-keygen -t ed25519 -f ~/.ssh/novasphere -N ""
```

## 2. Récupérer le code

```bash
git clone https://github.com/novasphere-eam-team/novasphere-terraform-5a.git
cd novasphere-terraform-5a
```

## 3. Credentials AWS

Les credentials du Learner Lab sont **temporaires** : ils changent à chaque nouvelle session.

1. AWS Academy → **Start Lab** → attendre le voyant vert.
2. **AWS Details** → **AWS CLI : Show** → copier le bloc complet dans `~/.aws/credentials`
   (Windows : `%USERPROFILE%\.aws\credentials`). Ne jamais le coller ailleurs.
3. Vérifier :

```bash
aws configure set region us-east-1
aws sts get-caller-identity
```

La commande doit afficher un ARN `assumed-role/voclabs/...`.

## 4. Backend du state

Le state Terraform est stocké dans un bucket S3 versionné et chiffré, avec verrouillage natif
(`use_lockfile = true`), un fichier par environnement :

| Environnement | Bucket | Clé |
|---|---|---|
| dev | `novasphere-tfstate-eam` | `novasphere/dev/terraform.tfstate` |
| prod | `novasphere-tfstate-eam` | `novasphere/prod/terraform.tfstate` |

Ce bucket se trouve dans le compte de lab du référent AWS (Elias AMARA) : c'est le state de
l'équipe, utilisé par la CI. Un autre compte de lab n'y a pas accès (`403 Forbidden`).

**Pour tester sur son propre lab**, créer un bucket personnel (une seule fois) :

```bash
BUCKET=novasphere-tfstate-<trigramme>
aws s3api create-bucket --bucket $BUCKET --region us-east-1
aws s3api put-bucket-versioning --bucket $BUCKET \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket $BUCKET \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
```

puis l'indiquer au `terraform init` (étape 7). Le fichier `versions.tf` n'est jamais modifié.

## 5. Variables

```bash
cd envs/dev                                    # ou envs/prod
cp terraform.tfvars.example terraform.tfvars   # puis renseigner son trigramme
```

| Variable | Exemple | Rôle |
|---|---|---|
| `owner` | `lgd` | Trigramme : nomme et tague les ressources (3 lettres minuscules) |
| `environment` | `dev` | `dev` ou `prod`, sans valeur par défaut, validé |
| `aws_region` | `us-east-1` | Région imposée par le lab |
| `instance_type` | `t3.micro` | Type des instances |
| `ssh_public_key_path` | `~/.ssh/novasphere.pub` | Clé publique déposée sur les instances |
| `admin_cidr` | `203.0.113.10/32` | IP autorisée en SSH sur l'instance monitoring ; vide = IP du poste |

`terraform.tfvars` est exclu par `.gitignore` et ne doit jamais être commité.

Le mot de passe applicatif n'est **jamais** dans un fichier, seulement dans le terminal :

```bash
export TF_VAR_db_password='<mot de passe de test>'      # Linux / macOS
$env:TF_VAR_db_password = '<mot de passe de test>'      # Windows PowerShell
```

## 6. Déployer par la CI (voie normale)

C'est ainsi que l'infrastructure de l'équipe est déployée, et ainsi que se fait la démonstration.

### Configuration GitHub (une fois, puis les clés AWS à chaque session)

Dépôt → **Settings → Secrets and variables → Actions** :

| Type | Nom | Valeur |
|---|---|---|
| Secret | `AWS_ACCESS_KEY_ID` | AWS Details du lab de déploiement |
| Secret | `AWS_SECRET_ACCESS_KEY` | AWS Details du lab de déploiement |
| Secret | `AWS_SESSION_TOKEN` | AWS Details du lab de déploiement |
| Secret | `DB_PASSWORD` | Mot de passe applicatif |
| Secret | `SSH_PUBLIC_KEY` | Contenu de la clé publique |
| Secret | `MODULE_TOKEN` | Token GitHub en lecture sur le dépôt du module |
| Variable | `TF_OWNER` | Trigramme du compte de déploiement (`eam`) |
| Variable | `ADMIN_CIDR` | IP d'administration en `/32` |

Dépôt → **Settings → Environments** : environnement `prod` avec un relecteur obligatoire.

Les trois clés AWS doivent être **remises à jour à chaque nouvelle session du lab**, sinon la CI
échoue au `terraform init` avec `403 Forbidden`. Avec GitHub CLI :

```bash
REPO=novasphere-eam-team/novasphere-terraform-5a
gh secret set AWS_ACCESS_KEY_ID     -R $REPO -b "$(aws configure get aws_access_key_id)"
gh secret set AWS_SECRET_ACCESS_KEY -R $REPO -b "$(aws configure get aws_secret_access_key)"
gh secret set AWS_SESSION_TOKEN     -R $REPO -b "$(aws configure get aws_session_token)"
```

### Le chaînage

```
branche ──► pull request ──► terraform-pr : fmt -check · validate · plan (dev + prod)
                                            └─► plan posté en commentaire de la PR
        ──► relecture + approbation ──► merge sur main
        ──► terraform-apply : apply-dev (depuis le fichier de plan)
                              └─► approbation de l'environnement prod
                              └─► apply-prod (depuis le fichier de plan)
```

1. Créer une branche, modifier le code, pousser, ouvrir une pull request vers `main`.
2. Lire les plans `dev` et `prod` postés en commentaire par la CI.
3. Faire approuver la PR par un autre membre, puis merger.
4. Suivre **Actions → terraform-apply** : `apply-dev` s'exécute, puis `apply-prod` attend
   l'approbation (**Review deployments → prod → Approve and deploy**).
5. L'adresse de chaque site est en fin des logs de l'apply : `alb_dns_name = "..."`.

## 7. Déployer en local (test sur son propre lab)

Réservé aux tests sur son propre compte, avec son bucket personnel (étape 4). Le state de l'équipe
n'est modifié que par la CI.

```bash
cd envs/dev
terraform init -backend-config="bucket=novasphere-tfstate-<trigramme>"
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

## 8. Vérifier

```bash
terraform output alb_dns_name
```

Ouvrir `http://<alb_dns_name>` (HTTP, pas HTTPS), après 2 à 3 minutes le temps que les instances
deviennent saines. La page affiche :

```
NovaSphere - DEV
Instance : ip-10-0-1-x          (ou ip-10-0-2-x : l'ALB répartit sur les deux zones)
Secret : lu depuis Parameter Store
Deploye par la CI
```

Contrôles complémentaires :

```bash
terraform plan -detailed-exitcode ; echo $?       # 0 = l'infrastructure correspond au code
terraform state pull | grep -c "<mot de passe>"   # 0 = le secret n'est pas dans le state
```

Détection de dérive par la CI : **Actions → terraform-apply → Run workflow** (branche `main`).
Le job `drift` est vert si l'infrastructure correspond au code, rouge sinon.

## 9. Détruire

**Obligatoire en fin de session** : un ALB ou un ASG oublié consomme le budget du lab.

```bash
cd envs/dev  && terraform destroy
cd ../prod   && terraform destroy
```

Avec les mêmes variables que pour le déploiement (dont `TF_VAR_db_password`). Pour le state de
l'équipe, utiliser les mêmes valeurs que la CI (`TF_VAR_admin_cidr`, `TF_VAR_generate_inventory=false`).

Vérifier qu'il ne reste rien :

```bash
aws ec2 describe-instances --region us-east-1 \
  --filters "Name=tag:Project,Values=NovaSphere" "Name=instance-state-name,Values=running,pending" \
  --query "Reservations[].Instances[].InstanceId" --output text      # doit être vide
```

## 10. Structure du dépôt

```
.github/workflows/
  terraform-pr.yml       PR : fmt -check, validate, plan dev et prod en commentaire
  terraform-apply.yml    merge : apply-dev, apply-prod protégé ; job drift déclenchable
envs/dev/
  versions.tf            backend S3 (clé novasphere/dev/…), providers, default_tags
  variables.tf           variables typées et validées ; db_password ephemeral sans défaut
  main.tf                VPC, Security Groups, Launch Template, ALB, ASG, secret, module monitoring
  outputs.tf             alb_dns_name, target_group_arn, vpc_id, asg_name, monitoring_public_ip
  bootstrap.sh.tftpl     script de démarrage (8 lignes) : lecture du secret, nginx, page
  terraform.tfvars.example
envs/prod/               mêmes fichiers ; seules la clé du backend et les valeurs diffèrent
global/oidc/             modèle OIDC GitHub → AWS (hors Learner Lab, non appliqué)
docs/architecture.png    schéma d'architecture
ansible/                 playbook d'origine du projet (non utilisé par le socle)
```

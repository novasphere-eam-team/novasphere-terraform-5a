# Sécurité

Ce document couvre ce que demande le cahier des charges : où vivent les secrets (§1 et §2),
la politique IAM que l'instance devrait avoir (§3), les résultats du scan Checkov
et le traitement de chaque règle (§5). Le §4 ajoute les règles réseau.

**En résumé** : aucun secret dans le code, le plan, le state ou les logs ; Security Groups fermés
(aucun SSH sur les instances web) ; 16 échecs Checkov au départ, 12 après corrections, 1 règle ignorée avec
justification dans le code ; chaque échec restant est accepté et expliqué.

## 1. Les secrets et où ils vivent

| Secret | Où il vit | Où il n'est jamais |
|---|---|---|
| Mot de passe applicatif `db_password` | SSM Parameter Store `/novasphere/<env>/db_password` (SecureString, chiffré KMS `aws/ssm`) ; fourni à Terraform par `TF_VAR_db_password` (terminal) ou le secret GitHub `DB_PASSWORD` | code, `.tfvars`, plan, state, `user_data`, historique Git, logs de CI |
| Credentials AWS | `~/.aws/credentials` du poste ; secrets GitHub `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` (session de lab, expirent en ~4 h) | code, provider, chat, commits |
| Token d'accès au dépôt du module | secret GitHub `MODULE_TOKEN` (lecture seule), injecté par `git config` dans la CI | code, logs (masqué par GitHub) |
| IP d'administration | variable GitHub `ADMIN_CIDR`, variable Terraform `admin_cidr` déclarée `sensitive` | plans, commentaires de PR, logs (dépôt public) |
| Clé SSH privée | poste de l'administrateur uniquement (seule la clé publique est envoyée à AWS) | dépôt |

### Pourquoi `value_wo`

- La variable `db_password` est `ephemeral = true` : Terraform ne l'enregistre ni dans le plan ni
  dans le state.
- `aws_ssm_parameter.db_password` utilise `value_wo` (attribut en écriture seule) : la valeur est
  envoyée à AWS à la création, puis **jamais relue ni stockée** par Terraform. Le plan affiche
  `value_wo = (write-only attribute)`.
- Pour changer le mot de passe, on incrémente `value_wo_version`.
- Avec l'ancien attribut `value`, le mot de passe apparaîtrait en clair dans le state S3.

### Lecture par l'instance

Au démarrage, `bootstrap.sh.tftpl` lit le paramètre avec `aws ssm get-parameter --with-decryption`,
grâce au profil d'instance (credentials temporaires via IMDSv2), et l'écrit dans
`/etc/novasphere/app.conf` (mode 0640). La page web affiche seulement « Secret : lu depuis
Parameter Store », jamais la valeur.

## 2. Contrôles de fuite effectués

| Contrôle | Commande | Résultat |
|---|---|---|
| Code | `git grep -iE "AKIA\|ASIA\|ghp_\|github_pat_"` | rien |
| Historique Git (les deux dépôts) | `git log --all -p \| grep -iE "AKIA\|ASIA\|ghp_\|github_pat_"` | rien |
| Fichiers suivis | `git ls-files \| grep -E '\.(tfvars\|pem\|env)$\|tfstate\|inventory.*\.ini\|tfplan'` | rien |
| Mot de passe de test dans l'historique | `git log --all -p \| grep "<mot de passe>"` | rien |
| State | `terraform state pull \| grep -c "<mot de passe>"` | **0** |
| `user_data` | contenu du Launch Template | aucun secret (Checkov CKV_AWS_46 réussi) |
| `db_password` | `variables.tf` | `ephemeral = true`, aucune valeur par défaut |

Le dépôt étant public, les logs de CI et les commentaires de PR sont lisibles par tous. Les
commentaires de PR qui contenaient l'IP d'administration ont été supprimés, la variable GitHub
`ADMIN_CIDR` a été remplacée par une adresse de documentation (`192.0.2.1/32`, RFC 5737, qui
n'appartient à personne : le SSH du monitoring est donc fermé en pratique), et `admin_cidr` est
déclarée `sensitive` (PR #5) : elle apparaît `(sensitive value)` dans tout plan futur.

### Limite des credentials de session

Les clés AWS stockées dans les secrets GitHub changent à chaque session du Learner Lab. Quand la
session change, la CI échoue dès le `terraform init` avec `403 Forbidden` sur le bucket de state :
il faut recopier les trois valeurs d'AWS Details dans les secrets. Avec le modèle OIDC
(`global/oidc/`), aucun secret ne serait stocké et un jeton temporaire serait émis à chaque run.

## 3. IAM : ce que le lab impose et ce que l'instance devrait avoir

Le Learner Lab refuse `iam:CreateRole` : les instances utilisent le profil existant
`LabInstanceProfile`, dont les droits sont bien plus larges que nécessaire. La politique idéale
d'un rôle dédié aux instances web serait :

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "LireUniquementLeSecretDeSonEnvironnement",
      "Effect": "Allow",
      "Action": ["ssm:GetParameter"],
      "Resource": "arn:aws:ssm:us-east-1:<compte>:parameter/novasphere/<env>/*"
    },
    {
      "Sid": "DechiffrerViaSSMUniquement",
      "Effect": "Allow",
      "Action": ["kms:Decrypt"],
      "Resource": "*",
      "Condition": { "StringEquals": { "kms:ViaService": "ssm.us-east-1.amazonaws.com" } }
    }
  ]
}
```

- Une instance `dev` ne peut pas lire le secret de `prod`, et inversement.
- L'instance monitoring n'a **aucun** profil IAM : elle n'a besoin d'aucun accès AWS
  (moindre privilège, voir CKV2_AWS_41 ci-dessous).

## 4. Réseau

- SG de l'ALB : seul le port 80 est ouvert à Internet.
- SG des instances web : port 80 **uniquement depuis le SG de l'ALB** ; aucun port SSH.
- Instance monitoring : SSH uniquement depuis un `/32` (`ADMIN_CIDR`), validation dans le module
  qui refuse `0.0.0.0/0`.
- IMDSv2 exigé (`http_tokens = "required"`) sur le Launch Template et sur l'instance du module :
  protège les credentials de l'instance contre le vol par SSRF.
- Volume racine de l'instance monitoring chiffré (module v1.3.0).

## 5. Analyse statique : Checkov

Commande : `checkov -d envs/dev --framework terraform --compact` (checkov 3.4).
`envs/prod` est identique à `envs/dev` (seule la clé du backend diffère), les résultats sont les mêmes.

### Évolution

| Étape | Réussis | Échoués | Ignorés (justifiés) |
|---|---|---|---|
| Scan initial | 25 | 16 | 0 |
| Après corrections (PR #1) | 28 | 12 | 1 |

### Corrigés

| Règle | Problème | Correction |
|---|---|---|
| CKV_AWS_79 | IMDSv1 autorisé | `metadata_options { http_tokens = "required" }` sur le Launch Template (PR #1) et sur l'instance du module ec2-server (v1.2.0) |
| CKV_AWS_23 (x2) | Règles egress sans description | `description` ajoutée sur les SG `alb` et `asg_web` (et dans le module v1.2.0) |
| CKV_AWS_131 | L'ALB transmet les en-têtes HTTP invalides | `drop_invalid_header_fields = true` sur `aws_lb.web` |

### Ignoré avec justification dans le code

| Règle | Justification |
|---|---|
| CKV_AWS_2 (listener HTTPS) | `#checkov:skip` sur `aws_lb_listener.http` : pas de nom de domaine ni de certificat ACM dans le Learner Lab, HTTPS impossible dans le socle (c'est l'extension « HTTPS » du cahier des charges) |

### Échecs restants, acceptés et expliqués

| Règle | Ressource | Pourquoi on l'accepte | Ce qu'on ferait en production |
|---|---|---|---|
| CKV_TF_1 | modules `vpc`, `monitoring` | Le cahier des charges impose un appel par tag (`?ref=vX.Y.Z`, `version = "~> 6.0"`). Nos tags ne sont jamais modifiés après publication (règle d'équipe) | Épingler le hash de commit |
| CKV_AWS_260 | SG `alb` | L'ALB est le point d'entrée public : le port 80 ouvert à Internet est voulu. Les instances, elles, n'acceptent que le SG de l'ALB | Port 443 uniquement, 80 redirigé |
| CKV_AWS_382 | SG `alb`, `asg_web` | Sortie libre : les instances doivent joindre les dépôts apt et l'API SSM, sans NAT ni VPC endpoint (interdits/payants dans le lab) | Egress de l'ALB limité au SG des instances sur le port 80 ; VPC endpoints SSM |
| CKV2_AWS_20, CKV_AWS_103, CKV_AWS_378 | ALB, listener, target group | Conséquences de l'absence de HTTPS (voir CKV_AWS_2) | Certificat ACM, listener 443 en TLS 1.2+, redirection 80 → 443 |
| CKV_AWS_150 | `aws_lb.web` | La protection contre la suppression empêcherait le `terraform destroy` exigé à chaque fin de session | Activée en prod |
| CKV_AWS_91 | `aws_lb.web` | Les logs d'accès demandent un bucket S3 dédié avec une politique pour le compte ELB : hors socle et coûteux dans le lab | Logs d'accès vers un bucket chiffré |
| CKV2_AWS_28 | `aws_lb.web` | AWS WAF est payant et hors socle | WAF avec règles managées AWS |
| CKV_AWS_337 | `aws_ssm_parameter.db_password` | Le paramètre est bien chiffré (SecureString, CKV2_AWS_34 réussi) avec la clé gérée `aws/ssm`. Une clé KMS client (CMK) est payante et sa politique demande des droits IAM refusés dans le lab | CMK dédiée, accès limité au rôle de l'instance |

### Module de l'équipe : terraform-aws-ec2-server

Commande : `checkov -d terraform-aws-ec2-server --framework terraform --compact`.

| Version | Réussis | Échoués |
|---|---|---|
| v1.2.0 | 9 | 5 |
| v1.3.0 | 11 | 3 |

Corrigés dans le module :

| Règle | Version | Correction |
|---|---|---|
| CKV_AWS_79 | v1.2.0 | IMDSv2 exigé sur l'instance (`http_tokens = "required"`) |
| CKV_AWS_23 | v1.2.0 | Description sur toutes les règles du Security Group |
| CKV_AWS_8 | v1.3.0 | Volume racine chiffré : `root_block_device { encrypted = true }` (clé gérée `aws/ebs`) |
| CKV_AWS_135 | v1.3.0 | `ebs_optimized = true` explicite (déjà le cas par défaut sur les t3) |

Échecs restants, acceptés :

| Règle | Pourquoi on l'accepte |
|---|---|
| CKV2_AWS_41 | Pas de profil IAM sur l'instance monitoring, **volontairement** : elle n'a besoin d'aucun accès AWS. Le seul profil disponible dans le lab, `LabInstanceProfile`, a des droits larges (dont la lecture du secret) : l'attacher pour satisfaire la règle élargirait les droits de l'instance, contraire au moindre privilège |
| CKV_AWS_382 | Sortie libre de l'instance (mises à jour apt), même raison que pour les SG de l'environnement |
| CKV_AWS_126 | Monitoring détaillé CloudWatch (1 min) payant ; le monitoring de base (5 min) suffit pour le projet |

### Contrôles importants qui réussissent

- CKV_AWS_46 : aucun secret en dur dans le `user_data`.
- CKV_AWS_41 : aucune clé AWS en dur dans le provider.
- CKV2_AWS_34 : le paramètre SSM est chiffré.
- CKV_AWS_24 / CKV_AWS_25 : aucun SSH ni RDP ouvert à Internet.
- CKV_AWS_88 : le Launch Template ne force pas d'IP publique sur les instances web.

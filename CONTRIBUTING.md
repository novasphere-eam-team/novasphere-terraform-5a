# Règles d'équipe

Les règles de base ont été posées à la séance 1 (S1). Elles ont été complétées au fil du projet,
quand un incident ou une nouvelle étape l'a demandé. La colonne « Origine » indique d'où vient
chaque règle.

## Rôles

| Membre | Responsabilités |
|---|---|
| Elias AMARA (`eam`) | Propriétaire de l'organisation GitHub et du compte AWS de déploiement ; socle S1 à S5 ; secrets GitHub, approbation de l'environnement `prod`, relecture et approbation des pull requests, destruction en fin de session |
| Marouf LAGUIDE (`lgd`) | Auteur des pull requests de correctifs (IMDSv2, module `v1.1.0` → `v1.3.0`, Checkov) et de la CI/CD GitHub Actions (S7, avec le modèle OIDC) |
| Johan MAILLARD (`jmd`) | Livrables, relecture et approbation des pull requests |

Toute pull request est relue par un membre **autre que son auteur**.

## Git et pull requests

| Règle | Origine |
|---|---|
| Une branche par changement (`fix/...`, `feat/...`, `ci/...`, `docs/...`), jamais de commit direct sur `main` | S1 |
| Toute modification passe par une pull request, relue et approuvée par un autre membre avant le merge | S1 |
| Le relecteur lit les plans `dev` et `prod` postés par la CI avant d'approuver : aucune destruction inattendue, aucune valeur sensible | S7, avec la CI |
| Chaque membre commite depuis son poste, sous son propre nom (`user.name` et `user.email` rattachés à son compte GitHub) | Cahier des charges |
| `terraform fmt -recursive` avant chaque commit ; la CI bloque si `fmt -check` échoue | S7 |
| Les fins de ligne des scripts sont forcées en LF par `.gitattributes`, à ne pas retirer : un script en CRLF ne s'exécute pas sur Linux | Incident (postes Windows) |

## Module de l'équipe

| Règle | Origine |
|---|---|
| `terraform-aws-ec2-server` est appelé par tag (`?ref=vX.Y.Z`), jamais par une branche | S2 |
| Un tag publié n'est jamais modifié ni supprimé : toute évolution donne une nouvelle version | S2 |
| Ordre : PR sur le module → merge → tag → PR sur le dépôt principal qui change le `ref` | S4 |
| Le module ne contient aucun bloc `provider` | S2 |

## Environnements et déploiement

| Règle | Origine |
|---|---|
| Jamais de state local : tout passe par le backend S3 | S1 |
| Pas de `terraform force-unlock` sans prévenir l'équipe | S1 |
| Un changement est fait en `dev` puis recopié à l'identique en `prod` ; les deux répertoires ne diffèrent que par la clé du backend | S3 |
| Le state de l'équipe n'est modifié que **par la CI** (merge sur `main`). En local : `plan` seulement, ou tests sur son propre lab avec un bucket personnel | S7 |
| Pas de NAT Gateway (coût horaire) | S4 |

## Secrets

| Règle | Origine |
|---|---|
| Jamais de secret dans le code, les `.tfvars` commités, le `user_data`, l'historique Git ou les logs | S1 |
| Jamais de credentials ni de token dans un chat, un commentaire de PR ou un message | Incident |
| `db_password` est fourni par `TF_VAR_db_password` (terminal) ou par le secret GitHub `DB_PASSWORD` | S5 |
| Les credentials AWS ne vont que dans `~/.aws/credentials` et dans les secrets GitHub | S5 |
| Le dépôt est public : toute valeur qui apparaîtrait dans un plan (une IP, par exemple) est déclarée `sensitive` | Incident (PR #5) |
| En cas de fuite : révoquer immédiatement (End Lab puis Start Lab, révocation du token), réécrire l'historique si nécessaire, prévenir l'équipe | S5 |

## Fin de session

| Règle | Origine |
|---|---|
| `terraform destroy` en `dev` **et** en `prod`, puis vérifier qu'aucune instance NovaSphere ne tourne (commande dans le README) | Cahier des charges |
| Avant chaque test de la CI et avant la soutenance : remettre à jour les trois secrets AWS dans GitHub | S7 |

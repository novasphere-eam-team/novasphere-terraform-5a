# Fiche de cadrage

Fiche de la séance 8, validée par l'intervenant (Hemerson KOFFI) avant le premier plan.

## Équipe

**Nom de l'équipe** : NovaSphere EAM (organisation GitHub `novasphere-eam-team`)

| Membre | Trigramme | Compte GitHub | Rôle |
|---|---|---|---|
| Elias AMARA | `eam` | `EliasA98` | **Référent Git** et **référent AWS** : organisation GitHub, compte de déploiement, state, configuration de la CI, relecture des pull requests |
| Marouf LAGUIDE | `lgd` | `Lm2111` | Sécurité et qualité du code (IMDSv2, module, Checkov), CI/CD GitHub Actions |
| Johan MAILLARD | `jmd` | `Joow94` | Livrables, relecture des pull requests |

Le trigramme est la valeur de la variable Terraform `owner` : il nomme et tague les ressources
(`novasphere-<env>-<trigramme>-...`). Le compte GitHub est celui sous lequel chaque membre commite.

**Compte AWS de la démonstration** : Learner Lab d'Elias AMARA, région `us-east-1`, bucket de state
`novasphere-tfstate-eam`.

## Contexte métier

NovaSphere est une plateforme web qui doit rester disponible en continu.
L'équipe d'exploitation veut un environnement de recette (`dev`) et un environnement de production (`prod`).
Les deux sont construits à partir du même code : ce qui est validé en recette est exactement ce qui part en production.
Chaque changement d'infrastructure est relu, tracé et déployé automatiquement.
Le mot de passe applicatif n'apparaît jamais, ni dans le code, ni dans l'état Terraform, ni dans les journaux.

## Ce que servent les instances

Une page web servie par nginx derrière un Application Load Balancer, qui affiche :

- l'environnement (« NovaSphere - DEV » ou « NovaSphere - PROD ») ;
- le nom de l'instance qui a répondu (preuve de la répartition sur deux zones) ;
- le statut de lecture du secret applicatif (« lu depuis Parameter Store »), sans jamais afficher
  sa valeur.

## Extension

**Aucune.** L'équipe concentre son effort sur un socle complet, déployé de bout en bout par la CI.
Aucune ressource supplémentaire n'est donc exigée, en particulier aucune NAT Gateway.

## Ce que l'équipe écarte, et pourquoi

| Écarté | Raison |
|---|---|
| NAT Gateway et subnets privés | Coût horaire dans le lab, inutile pour une page statique |
| HTTPS | Pas de nom de domaine ni de certificat ACM dans le Learner Lab |
| OIDC GitHub → AWS | Création du fournisseur et du rôle refusée dans le lab ; modèle écrit dans `global/oidc/` |
| Workspaces Terraform | Refusés par le cahier des charges ; répertoires `envs/dev` et `envs/prod` à la place |
| Rôle IAM dédié aux instances | `iam:CreateRole` refusé ; `LabInstanceProfile` utilisé, politique idéale dans SECURITE.md |

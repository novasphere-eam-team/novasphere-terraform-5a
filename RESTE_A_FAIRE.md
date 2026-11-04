# Reste-à-faire et répartition

Fiche de la séance 9 reconstituée à partir de l'historique Git et des pull requests du dépôt.
Chaque item est nominatif ; la colonne « Trace » renvoie à ce qui le prouve dans le dépôt.

## Socle construit pendant la semaine intensive (S1 à S5)

| Étape | Contenu | Qui | Trace |
|---|---|---|---|
| S1 | Backend S3 versionné et chiffré, verrouillage natif `use_lockfile` | Elias AMARA | commit `0fed02a` |
| S2 | Module `ec2-server` extrait, publié dans son dépôt, tag `v1.0.0`, validation du CIDR | Elias AMARA | commits `73403f5`, `515524b` |
| S3 | Environnements `envs/dev` et `envs/prod`, un state par environnement | Elias AMARA | commit `cc01123` |
| S4 | VPC sur deux zones sans NAT, ALB, Launch Template, ASG, Security Groups chaînés | Elias AMARA | commits `a3a4291`, `aa8e897` |
| S5 | Secret dans Parameter Store en `value_wo`, `LabInstanceProfile`, bootstrap | Elias AMARA | commits `c9f3dbd`, `1b182c7` |
| | Passage à l'organisation GitHub `novasphere-eam-team` | Elias AMARA | commit `26c43aa` |

## Reste-à-faire de la séance 9

| Tâche | Qui | Pour quand | État | Trace |
|---|---|---|---|---|
| `.gitignore` (`*.tfvars`, `ansible/inventory*.ini`, fichiers de plan) et `.gitattributes` (LF) | Marouf LAGUIDE | 05/11/2026 12h | Fait | PR #1, #2, #4 |
| IMDSv2 exigé sur le Launch Template et sur l'instance du module | Marouf LAGUIDE | 05/11/2026 12h | Fait | PR #1, module `v1.2.0` |
| Module : variable `role`, `create_before_destroy`, `versions.tf`, chiffrement EBS | Marouf LAGUIDE | 05/11/2026 12h | Fait | module `v1.1.0` → `v1.3.0`, PR #2, #3 |
| Scan Checkov, corrections et justifications | Marouf LAGUIDE | 05/11/2026 12h | Fait | PR #1, module `v1.3.0`, SECURITE.md |
| Workflows GitHub Actions (PR, apply, dérive), page DEV/PROD par `templatefile` | Marouf LAGUIDE | 05/11/2026 12h | Fait | PR #4 |
| Dérive en déclenchement manuel, `admin_cidr` sensible | Marouf LAGUIDE | 05/11/2026 12h | Fait | PR #5 |
| Secrets et variables GitHub, environnement `prod` protégé, dépôts publics | Elias AMARA | 05/11/2026 12h | Fait | Settings du dépôt |
| Relecture et approbation des pull requests (plans `dev` et `prod` lus avant approbation) | Johan MAILLARD, Elias AMARA | chaque PR | Fait | approbations sur les PR #1 à #6 |
| Premier déploiement dev puis prod par la CI, pages vérifiées | Elias AMARA, Marouf LAGUIDE | 05/11/2026 12h | Fait | Actions : `terraform-apply` #1 |
| README, ARCHITECTURE, SECURITE, CONTRIBUTING, CADRAGE, RESTE_A_FAIRE | Johan MAILLARD, Marouf LAGUIDE | 05/11/2026 12h | Fait | PR des livrables |
| Contrôles de fuite (code, historique, fichiers suivis, state) | Marouf LAGUIDE, Elias AMARA | 05/11/2026 12h | Fait | SECURITE.md §2 |
| Tag `rendu-final` | Équipe | 05/11/2026 12h | À faire avant le 05/11/2026 12h | tag Git |
| Test de dérive (job `drift`, déclenché à la main) | Elias AMARA, Marouf LAGUIDE | 05/11/2026 12h | Fait : vert en dev et prod après déploiement (run #7) ; un écart réel avait été détecté et expliqué la veille (IP publique changée par l'arrêt du lab) | Actions : `terraform-apply` #5 et #7 |
| Destruction dev et prod après chaque session | Elias AMARA | chaque session | Fait (dernière destruction : 04/11/2026) | `terraform destroy` dev et prod |
| Répétition de la démonstration : PR, plan en commentaire, merge, apply dev, approbation, apply prod, pages DEV et PROD | Équipe | soutenance | Fait le 04/11/2026 (PR #6, run `terraform-apply` #6) | PR #6 |

## Signatures

Chaque membre a relu la fiche et valide les items qui portent son nom.

<div align="center">

| Membre | Signature | Date |
|:---:|:---:|:---:|
| Elias AMARA | `eam` | 04/11/2026 |
| Marouf LAGUIDE | `lgd` | 04/11/2026 |
| Johan MAILLARD | `jmd` | 04/11/2026 |

</div>

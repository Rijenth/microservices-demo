# ADR-001 : Déploiement AWS d'Online Boutique via Terraform

**Date :** 2026-03-30
**Statut :** Accepté
**Décideurs :** Équipe Plateforme

---

## Contexte

Online Boutique doit être déployable sur AWS en tant qu'alternative à GCP. L'infrastructure doit être reproductible, versionnée et sécurisée. La région cible est `eu-west-3` (Paris).

---

## Décision

L'infrastructure AWS est provisionnée via **Terraform** avec une architecture modulaire (`terraform/aws/modules/`).

### Architecture déployée

```
Internet
    │
   [WAF]
    │
   [ALB]  ← eu-west-3a + eu-west-3b
    │
   [EC2 t3.small]  ← subnet public eu-west-3a
    │
   [RDS]           ← subnet public eu-west-3b
```

| Module | Ressources | Notes |
|--------|-----------|-------|
| `vpc` | VPC, 2 subnets publics, routing | Multi-AZ : eu-west-3a / eu-west-3b |
| `security` | Security Groups (EC2, RDS, ALB) | Isolation réseau par SG |
| `ec2` | Instance t3.small | AMI `ami-04b8aa78946b54b56` |
| `rds` | Instance DB | Credentials via module `secrets` |
| `alb` | Application Load Balancer | Cible l'instance EC2 |
| `waf` | Web ACL associée à l'ALB | Protection applicative L7 |
| `iam` | Rôles IAM, OIDC (optionnel EKS) | IRSA si `eks_oidc_issuer_url` fourni |
| `secrets` | AWS Secrets Manager | Stockage credentials DB et Redis |

---

## Alternatives considérées

| Option | Raison du rejet |
|--------|----------------|
| ECS Fargate | Plus complexe à intégrer avec les SGs existants, surcoût pour un démo |
| Déploiement EC2 sans ALB | Pas de TLS, pas de haute disponibilité, pas de WAF possible |
| Credentials en variables d'environnement shell | Non reproductible, risque d'exposition dans les logs CI |

---

## Conséquences

### Positives

- Structure modulaire : chaque composant est isolé et testable indépendamment
- Secrets Manager évite les credentials en dur dans le code
- WAF activé dès le départ sur l'ALB

### Points d'attention

- Les subnets RDS et EC2 sont **publics** — à remplacer par des subnets privés en production
- `terraform.tfvars` **ne doit pas être commité** : ajouter au `.gitignore` et utiliser des variables d'environnement `TF_VAR_*` ou un outil comme AWS Vault
- Les credentials AWS sont passés en variables Terraform (`aws_access_key` / `aws_secret_key`) : préférer un rôle IAM assumé ou les credentials par défaut de la machine (`~/.aws/credentials`)
- Pas de remote state configuré : risque de conflits en équipe (recommandé : S3 + DynamoDB lock)

---

## Décisions liées

- ADR-002 (à rédiger) : Stratégie de gestion du remote state Terraform
- ADR-003 (à rédiger) : Passage des subnets publics à privés pour RDS et EC2

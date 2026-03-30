# RB-002 : Reprise sur incident EC2 (instance down / unreachable)

**Dernière mise à jour :** 2026-03-30
**Propriétaire :** Équipe Plateforme
**Durée estimée :** 5–30 min selon le cas

---

## Prérequis

- Accès AWS Console ou AWS CLI configuré
- Accès Terraform (`terraform/aws/`)
- Clé SSH `rijenth_paris`

---

## Diagnostic initial

### 1. Vérifier l'état de l'instance via AWS CLI

```sh
aws ec2 describe-instance-status \
  --region eu-west-3 \
  --filters "Name=instance-state-name,Values=running,stopped,terminated" \
  --query "InstanceStatuses[*].{ID:InstanceId,State:InstanceState.Name,Status:SystemStatus.Status}" \
  --output table
```

### 2. Vérifier les health checks de l'ALB

```sh
aws elbv2 describe-target-health \
  --region eu-west-3 \
  --target-group-arn <TARGET_GROUP_ARN>
```

> Le Target Group ARN est disponible via `terraform output`.

---

## Cas 1 — Instance stoppée

```sh
# Démarrer l'instance
aws ec2 start-instances --region eu-west-3 --instance-ids <INSTANCE_ID>

# Attendre qu'elle soit running
aws ec2 wait instance-running --region eu-west-3 --instance-ids <INSTANCE_ID>
```

Vérifier que l'application redémarre automatiquement (si configuré en service systemd/docker).

---

## Cas 2 — Instance unreachable (SSH impossible, app KO)

### Option A : Reboot

```sh
aws ec2 reboot-instances --region eu-west-3 --instance-ids <INSTANCE_ID>
```

Attendre 2–3 minutes puis retenter la connexion SSH.

### Option B : Remplacement de l'instance via Terraform

Si le reboot ne suffit pas :

```sh
cd terraform/aws/

# Détruire uniquement le module EC2
terraform destroy -target=module.ec2

# Recréer l'instance
terraform apply -target=module.ec2
```

> L'ALB redirigera automatiquement le trafic vers la nouvelle instance une fois les health checks passés.

---

## Cas 3 — Perte de données / corruption

1. Identifier le dernier snapshot EBS disponible (si snapshots activés)
2. Créer un nouveau volume depuis le snapshot
3. Attacher le volume à la nouvelle instance
4. Redéployer l'application (voir RB-001)

---

## Vérification post-reprise

```sh
# Tester l'accès via l'ALB
curl -I http://<ALB_DNS_NAME>

# Vérifier les health checks
aws elbv2 describe-target-health \
  --region eu-west-3 \
  --target-group-arn <TARGET_GROUP_ARN>
```

---

## Critères de succès

- Instance en état `running`
- Health checks ALB en `healthy`
- Application accessible via l'ALB (`HTTP 200`)

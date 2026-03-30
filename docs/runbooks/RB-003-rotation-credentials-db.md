# RB-003 : Rotation des credentials de la base de données

**Dernière mise à jour :** 2026-03-30
**Propriétaire :** Équipe Plateforme
**Durée estimée :** 15–25 min

---

## Prérequis

- Accès AWS CLI avec droits `secretsmanager` et `rds`
- Accès Terraform (`terraform/aws/`)
- Accès SSH à l'EC2 pour redémarrer l'application

---

## Contexte

Les credentials DB sont stockés dans **AWS Secrets Manager** via le module `terraform/aws/modules/secrets/`. La rotation doit être effectuée dans Secrets Manager **et** propagée à Terraform pour éviter toute dérive d'état.

---

## Étapes

### 1. Identifier le secret actuel

```sh
aws secretsmanager list-secrets \
  --region eu-west-3 \
  --query "SecretList[?contains(Name, 'rijenth-online-boutique')].{Name:Name,ARN:ARN}" \
  --output table
```

### 2. Générer un nouveau mot de passe

```sh
NEW_PASSWORD=$(aws secretsmanager get-random-password \
  --region eu-west-3 \
  --password-length 24 \
  --require-each-included-type \
  --query RandomPassword \
  --output text)
echo "Nouveau mot de passe généré (ne pas logger en prod)"
```

### 3. Mettre à jour le mot de passe sur RDS

```sh
aws rds modify-db-instance \
  --region eu-west-3 \
  --db-instance-identifier <RDS_INSTANCE_ID> \
  --master-user-password "$NEW_PASSWORD" \
  --apply-immediately
```

Attendre que la modification soit appliquée :

```sh
aws rds wait db-instance-available \
  --region eu-west-3 \
  --db-instance-identifier <RDS_INSTANCE_ID>
```

### 4. Mettre à jour le secret dans Secrets Manager

```sh
aws secretsmanager put-secret-value \
  --region eu-west-3 \
  --secret-id <SECRET_ARN> \
  --secret-string "{\"username\":\"admin\",\"password\":\"$NEW_PASSWORD\"}"
```

### 5. Mettre à jour la variable Terraform

Modifier `terraform/aws/terraform.tfvars` **localement** (ne pas commiter) :

```hcl
db_password = "<NEW_PASSWORD>"
```

Appliquer pour synchroniser l'état Terraform :

```sh
cd terraform/aws/
terraform apply -target=module.rds
```

### 6. Redémarrer l'application pour prendre en compte le nouveau mot de passe

```sh
ssh -i ~/.ssh/rijenth_paris.pem ec2-user@<EC2_PUBLIC_IP>

# Redémarrer les pods qui utilisent la DB
kubectl rollout restart deployment/cartservice
kubectl rollout status deployment/cartservice
```

---

## Vérification post-rotation

```sh
# Vérifier que le secret est bien mis à jour
aws secretsmanager get-secret-value \
  --region eu-west-3 \
  --secret-id <SECRET_ARN> \
  --query SecretString \
  --output text

# Vérifier les logs cartservice (seul service avec dépendance DB/Redis)
kubectl logs deployment/cartservice --tail=50
```

---

## Critères de succès

- Connexion RDS fonctionnelle depuis l'application
- Aucune erreur de connexion dans les logs du `cartservice`
- L'ancien mot de passe ne permet plus de se connecter

---

## Sécurité

- Ne jamais commiter `terraform.tfvars` (ajouter `*.tfvars` au `.gitignore`)
- Préférer `TF_VAR_db_password` comme variable d'environnement en CI/CD :
  ```sh
  export TF_VAR_db_password="<NEW_PASSWORD>"
  terraform apply
  ```

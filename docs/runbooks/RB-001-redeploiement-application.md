# RB-001 : Redéploiement d'une nouvelle version de l'application

**Dernière mise à jour :** 2026-03-30
**Propriétaire :** Équipe Plateforme
**Durée estimée :** 10–20 min

---

## Prérequis

- Accès AWS IAM avec droits EC2
- Clé SSH `rijenth_paris` disponible localement
- Terraform installé (`>= 1.0`)
- IP publique de l'instance EC2 (voir outputs Terraform)

```sh
cd terraform/aws/
terraform output
```

---

## Étapes

### 1. Vérifier l'état de l'infrastructure

```sh
terraform plan
```

S'assurer qu'aucun changement non intentionnel n'est en attente.

### 2. Se connecter à l'instance EC2

```sh
ssh -i ~/.ssh/rijenth_paris.pem ec2-user@<EC2_PUBLIC_IP>
```

### 3. Arrêter les conteneurs applicatifs en cours

```sh
# Si déploiement via Docker Compose
docker compose down

# Si déploiement via kubectl (cluster local sur l'EC2)
kubectl delete -f /opt/microservices-demo/release/kubernetes-manifests.yaml
```

### 4. Récupérer la nouvelle version

```sh
cd /opt/microservices-demo
git pull origin main
```

Ou transférer les manifestes mis à jour :

```sh
# Depuis votre machine locale
scp -i ~/.ssh/rijenth_paris.pem \
  release/kubernetes-manifests.yaml \
  ec2-user@<EC2_PUBLIC_IP>:/opt/microservices-demo/release/
```

### 5. Appliquer la nouvelle version

```sh
# Via kubectl
kubectl apply -f /opt/microservices-demo/release/kubernetes-manifests.yaml

# Vérifier que tous les pods sont Running
kubectl get pods --watch
```

### 6. Vérifier le bon fonctionnement

```sh
# Vérifier les logs du frontend
kubectl logs deployment/frontend --tail=50

# Tester l'accès HTTP via l'ALB
curl -I http://<ALB_DNS_NAME>
```

L'ALB DNS est disponible via :

```sh
terraform output alb_dns_name
```

### 7. Rollback si nécessaire

```sh
git checkout <COMMIT_PRECEDENT>
kubectl apply -f release/kubernetes-manifests.yaml
```

---

## Critères de succès

- Tous les pods en état `Running`
- L'ALB répond avec un `HTTP 200`
- Aucune erreur dans les logs du `frontend` et du `checkoutservice`

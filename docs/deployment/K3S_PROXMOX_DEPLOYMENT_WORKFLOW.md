# k3s on Proxmox Deployment Workflow

> **Legacy and unmaintained.** Hosted deploys run on Dokploy. See [Dokploy](DOKPLOY.md) and [Deployment Overview](DEPLOYMENT_OVERVIEW.md). This runbook stays in the tree as a record of the old cluster path. Nothing in `.github/workflows/` applies these manifests.

This workflow describes a former Kubernetes path on Proxmox with Cloudflare Tunnel-only ingress.

## Prerequisites

- Proxmox VE node with sufficient free resources
- Ubuntu 24.04 cloud image available on Proxmox storage
- DNS and Cloudflare Tunnel prepared
- Container registry credentials for app images

## Step 1: Create Proxmox k3s Template

Use:

```bash
scripts/proxmox/create-k3s-template.sh \
  --template-id 9001 \
  --name k3s-ubuntu-2404-template \
  --storage local-zfs \
  --image-path /var/lib/vz/template/iso/ubuntu-24.04-server-cloudimg-amd64.img
```

## Step 2: Clone Control Node from Template

```bash
scripts/proxmox/clone-k3s-node.sh \
  --template-id 9001 \
  --vm-id 9101 \
  --name k3s-control-01 \
  --target-node pve \
  --ip-cidr 10.0.10.21/24 \
  --gateway 10.0.10.1 \
  --role control
```

The IP/CIDR and gateway above are **example values** — replace them with addresses from your own network. Both `scripts/proxmox/create-k3s-template.sh` and `scripts/proxmox/clone-k3s-node.sh` exist in the repository.

## Step 3: Install k3s Control Plane

On control node:

```bash
curl -sfL https://get.k3s.io | sh -
kubectl get nodes
```

## Step 4: Provision ArgoCD Management VM/LXC

Follow `docs/archive/historical-reports/deployment/ARGOCD_PROXMOX_MANAGEMENT_VM.md`.

## Step 5: Bootstrap the cluster

There is no `k8s/bootstrap/root-app.yaml` in this repository. ArgoCD bootstrap manifests belong in your own GitOps repository; the manifests available here are the shared base under `config/kubernetes/base/` (namespace, HPAs, PDBs, network policies):

```bash
kubectl apply -f config/kubernetes/base/namespace.yaml
kubectl apply -f config/kubernetes/base/
kubectl -n argocd get applications,applicationsets
```

## Step 6: Deploy Cloudflare Tunnel-Only Ingress

The repository contains `config/cloudflared/config.yml` as the Tunnel configuration source. The older `k8s/deployments/overlays/managed/cloudflared-tunnel.yaml`, `k8s/deployments/overlays/managed/cloudflared-admin-tunnel.yaml` and `k8s/apps/managed/ingress-cloudflared` paths are **planned, not present** — provide those overlays in your GitOps repo before applying them:

```bash
# Example once you have supplied the overlay in your own repository:
# kubectl kustomize <your-gitops-repo>/apps/managed/ingress-cloudflared > ingress-cloudflared-render.yaml
```

For the supported production image path, see [Web Deploy](../operations/cicd/WEB_DEPLOY.md).

## Step 7: Verify Deployment Health

```bash
bash scripts/verify-k8s-tunnel-only.sh
bash scripts/integration-test-deployments.sh --e2e-deployment
```

## Step 8: Expansion to Multi-Node (When Needed)

- Clone worker nodes from the same template
- Join workers using control-plane token
- Enable multi-node scheduling and scaling policies

## Rollback Drill

- Trigger a controlled bad rollout in staging
- Verify health gate failure path
- Confirm rollback to previous ArgoCD revision
- Capture and review diagnostics logs/events

# ☸️ Kubernetes The Hard Way — Multi-Arch (Incus / OCI ARM64 & x86_64)

> **Projet d'ingénierie système & infrastructure** dans le cadre d'une reconversion vers les métiers du DevOps / Cloud & SRE.

Ce dépôt documente mon implémentation de **Kubernetes The Hard Way** (adapté du projet original de Kelsey Hightower). L'objectif est de monter un cluster Kubernetes fonctionnel **partir de zéro**, sans outil d'abstraction (`kubeadm`, `k3s`, etc.), afin d'en maîtriser la théorie, la sécurité TLS, la pile réseau et le fonctionnement interne de chaque composant.

---

## 🎯 Démarche d'Apprentissage & Méthodologie

### 1. Compréhension manuelle avant automatisation
* **Mémoire musculaire & Fondations :** Je réalise chaque étape d'abord **à la main** (génération de la PKI, configuration `etcd`, `containerd`, `kubelet`, routes CNI) pour comprendre les rouages du système.
* **Du système aux scripts :** Une fois la mécanique validée, j'automatise le déploiement complet via des scripts Bash et `yq` pour rendre la plateforme reproductible en une commande.

### 2. Workflow d'apprentissage : L'IA comme tuteur socratique
Dans ce projet, j'utilise l'IA générative non pas comme un générateur de code clé en main, mais comme un **tuteur socratique** et un **sparring-partner technique** :
* **Questionnement guidé :** L'IA est paramétrée pour interroger mes choix d'architecture (pourquoi tel composant, quel impact sur la sécurité ou les performances) plutôt que de me donner les réponses.
* **Analyse d'erreurs :** En cas de dysfonctionnement, j'utilise l'IA pour isoler les mécanismes sous-jacents du noyau Linux (cgroups, namespaces, iptables, sockets) au lieu d'appliquer des correctifs aveugles.
* **Validation des concepts :** Chaque étape franchie fait l'objet d'une revue critique afin de consolider mes acquis théoriques et ma capacité à expliquer le « pourquoi » derrière chaque configuration.

---

## 🏗️ Architecture & Choix Techniques

### Pourquoi Incus (Conteneurs système LXC) plutôt que des VM ?
Sur les instances Cloud ARM64 (comme Oracle Cloud A1), la *nested virtualization* (virtualisation emboîtée KVM) n'est pas activée. Pour dépasser cette contrainte sans perdre en isolation :
* J'utilise **Incus** pour faire tourner des **conteneurs système** (Debian 12).
* Chaque conteneur possède son propre `systemd`, sa propre pile réseau et sa RAM allouée, tout en partageant le noyau hôte.
* **Résultat :** Un cluster à 4 nœuds hyper léger, avec zéro surcharge de virtualisation et une empreinte mémoire optimale.

### Support Multi-Environnement
* **Cloud 24/7 (ARM64 / aarch64) :** Hébergé sur l'offre *OCI Always Free* (4 OCPUs, 24 Go RAM) pour des tests continus.
* **Local / Lab (x86_64 / amd64) :** Exécutable sur environnement de dev local (AMD Ryzen 5).

---

## 📊 Topologie du Cluster

Le déploiement est piloté par un fichier de déclaration unifié (`config.yaml`) :

| Nœud | Rôle | CPU | RAM | Stockage | Profil Incus |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `jump-host` | Bastion & Admin | 1 vCPU | 1 GiB | 10 GiB | `default` |
| `server` | Control Plane & etcd | 2 vCPU | 4 GiB | 20 GiB | `default`, `k8s` |
| `node-0` | Worker Node 0 | 2 vCPU | 4 GiB | 20 GiB | `default`, `k8s` |
| `node-1` | Worker Node 1 | 2 vCPU | 4 GiB | 20 GiB | `default`, `k8s` |

---

## 🛠️ Guide d'Utilisation

### Prérequis
* Un serveur sous Linux (Ubuntu/Debian recommandés) sous x86_64 ou ARM64.
* **Incus** installé et initialisé (`incus admin init`).
* **yq** (parseur YAML) : `sudo snap install yq`

### Installation & Déploiement

1. **Cloner le dépôt :**
   ```bash
   git clone [https://github.com/votre-utilisateur/k8s-the-hard-way-incus.git](https://github.com/votre-utilisateur/k8s-the-hard-way-incus.git)
   cd k8s-the-hard-way-incus

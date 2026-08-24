#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${1:-list.yaml}"

# 1. Vérification des dépendances
if ! command -v yq &> /dev/null; then
    echo "❌ Erreur : 'yq' n'est pas installé."
    exit 1
fi

if ! command -v incus &> /dev/null; then
    echo "❌ Erreur : 'incus' n'est pas installé."
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Erreur : Fichier '$CONFIG_FILE' introuvable."
    exit 1
fi

# 2. Préparation du stockage et du réseau Incus
echo "==> [1/4] Vérification de l'infrastructure Incus (Storage & Network)..."

# Stockage
if ! incus storage show default &>/dev/null; then
    echo "   • Création du pool de stockage 'default'..."
    incus storage create default dir
    incus profile device add default root disk path=/ pool=default || true
fi

# Réseau personnalisé extrait du YAML
NET_NAME=$(yq -r '.network.name // "k8s-net"' "$CONFIG_FILE")

if ! incus network show "$NET_NAME" &>/dev/null; then
    echo "   • Création du réseau '$NET_NAME'..."
    incus network create "$NET_NAME"
    incus profile device add default eth0 nic network="$NET_NAME" name=eth0 || true
fi

# 3. Préparation du noyau hôte pour Kubernetes
echo "==> [2/4] Chargement des modules noyau sur l'hôte..."
sudo modprobe overlay || true
sudo modprobe br_netfilter || true

# 4. Création du profil Incus 'k8s' si nécessaire
if ! incus profile show k8s &>/dev/null; then
    echo "==> [3/4] Création du profil Incus 'k8s'..."
    incus profile create k8s
    incus profile set k8s security.nesting=true
    incus profile set k8s security.privileged=true
    incus profile set k8s linux.kernel_modules overlay,br_netfilter,ip_tables,ip6_tables,netlink_diag,nf_nat,x_tables
else
    echo "==> [3/4] Profil Incus 'k8s' déjà présent."
fi

# 5. Lecture du YAML et déploiement des conteneurs
echo "==> [4/4] Déploiement des conteneurs..."

INCUS_IMG=$(yq -r '.os_images[0].incus_name' "$CONFIG_FILE")
NODE_COUNT=$(yq -r '.vms | length' "$CONFIG_FILE")

for ((i=0; i<$NODE_COUNT; i++)); do
    NAME=$(yq -r ".vms[$i].name" "$CONFIG_FILE")
    CPU=$(yq -r ".vms[$i].cpu" "$CONFIG_FILE")
    RAM=$(yq -r ".vms[$i].ram" "$CONFIG_FILE")
    STORAGE=$(yq -r ".vms[$i].storage" "$CONFIG_FILE")

    HAS_PROFILES=$(yq -r ".vms[$i] | has(\"profiles\")" "$CONFIG_FILE")

    if [ "$HAS_PROFILES" = "true" ]; then
        PROFILES_ARGS=""
        PROFILES_COUNT=$(yq -r ".vms[$i].profiles | length" "$CONFIG_FILE")
        for ((j=0; j<$PROFILES_COUNT; j++)); do
            PROF=$(yq -r ".vms[$i].profiles[$j]" "$CONFIG_FILE")
            PROFILES_ARGS="$PROFILES_ARGS -p $PROF"
        done
    else
        PROFILES_ARGS="-p default -p k8s"
    fi

    echo "--------------------------------------------------"
    echo "🚀 Lancement de : $NAME"
    echo "   • Image     : images:$INCUS_IMG"
    echo "   • Réseau    : $NET_NAME"
    echo "   • Limites   : $CPU vCPU | $RAM RAM | $STORAGE Disque"
    echo "   • Profils   : $PROFILES_ARGS"

    if incus info "$NAME" &>/dev/null; then
        echo "⚠️  L'instance '$NAME' existe déjà. Ignorée."
    else
        incus launch "images:$INCUS_IMG" "$NAME" \
            $PROFILES_ARGS \
            -c limits.cpu="$CPU" \
            -c limits.memory="$RAM" \
            -d root,size="$STORAGE"
    fi
done

echo "--------------------------------------------------"
echo "✅ Déploiement terminé ! Résumé des instances :"
echo ""
incus list
incus network list

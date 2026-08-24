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

# 2. Suppression des conteneurs
echo "==> [1/2] Suppression des conteneurs listés dans $CONFIG_FILE..."

NODE_COUNT=$(yq -r '.vms | length' "$CONFIG_FILE")

for ((i=0; i<$NODE_COUNT; i++)); do
    NAME=$(yq -r ".vms[$i].name" "$CONFIG_FILE")

    if incus info "$NAME" &>/dev/null; then
        echo "🗑️  Suppression de : $NAME"
        incus delete -f "$NAME"
    else
        echo "ℹ️  L'instance '$NAME' n'existe pas. Ignorée."
    fi
done

# 3. Détachement et suppression du réseau
NET_NAME=$(yq -r '.network.name // "k8s-net"' "$CONFIG_FILE")

echo "==> [2/2] Nettoyage du réseau '$NET_NAME'..."

# Retrait de la carte du profil default pour libérer le réseau
if incus profile device show default eth0 &>/dev/null; then
    echo "   • Détachement de 'eth0' du profil default..."
    incus profile device remove default eth0
fi

# Suppression du réseau virtuel
if incus network show "$NET_NAME" &>/dev/null; then
    echo "🗑️  Suppression du réseau : $NET_NAME"
    incus network delete "$NET_NAME"
else
    echo "ℹ️  Le réseau '$NET_NAME' n'existe pas. Ignoré."
fi

echo "--------------------------------------------------"
echo "✅ Nettoyage complet terminé !"
echo ""
incus list
incus profile device remove default eth0
incus network list

#!/usr/bin/env bash
# Certificat de distribution Apple sans Mac (Git Bash sous Windows, ou tout
# shell avec openssl). Voir docs/TESTFLIGHT.md.
#
#   tools/ios/certificat.sh demande              → verger.key + verger.csr
#   tools/ios/certificat.sh p12 distribution.cer → verger.p12 (+ mot de passe)
#   tools/ios/certificat.sh base64 FICHIER       → contenu à coller en secret
#
# La clé privée (verger.key, verger.p12) reste sur votre machine : ne la
# commitez pas, ne l'envoyez à personne. Seul le secret GitHub la contient.
set -euo pipefail
export MSYS_NO_PATHCONV=1 # Git Bash : ne pas convertir « /CN=… » en chemin
dossier="${VERGER_CERT_DIR:-$HOME/verger-ios}"
mkdir -p "$dossier"
# Fichier donné en argument, lu avant de changer de dossier (chemin relatif).
fichier_arg="${2:-}"
case "$fichier_arg" in
  '' | /* | [A-Za-z]:*) ;; # absent, absolu, ou « C:/… » / « C:\… »
  *) fichier_arg="$PWD/$fichier_arg" ;;
esac
cd "$dossier"

case "${1:-}" in
  demande)
    openssl genrsa -out verger.key 2048
    openssl req -new -key verger.key -out verger.csr -subj "/CN=Verger/C=FR"
    echo
    echo "Demande créée : $dossier/verger.csr"
    echo "→ À téléverser sur developer.apple.com (certificat « Apple Distribution »)."
    ;;
  p12)
    cer="${fichier_arg:?Chemin du fichier .cer téléchargé chez Apple}"
    # openssl est un programme Windows sous Git Bash : il ne comprend pas les
    # chemins « /c/Users/… ». On copie le certificat ici (cp, lui, les
    # comprend) et openssl ne lit qu'un nom de fichier local. Copie complète
    # puis renommage : jamais de distribution.cer tronqué.
    if ! [ "$cer" -ef distribution.cer ]; then
      cp "$cer" distribution.cer.tmp
      mv distribution.cer.tmp distribution.cer
    fi
    openssl x509 -inform DER -in distribution.cer -out distribution.pem
    mdp="$(openssl rand -hex 12)"
    # -legacy : format accepté par le trousseau macOS (openssl 3).
    if ! openssl pkcs12 -export -legacy -inkey verger.key -in distribution.pem \
        -out verger.p12 -passout "pass:$mdp" 2>/dev/null; then
      openssl pkcs12 -export -inkey verger.key -in distribution.pem \
        -out verger.p12 -passout "pass:$mdp"
    fi
    echo
    echo "Certificat créé : $dossier/verger.p12"
    echo "Secret IOS_P12_PASSWORD : $mdp"
    echo "Secret IOS_P12_BASE64   : lancez « $0 base64 $dossier/verger.p12 »"
    ;;
  base64)
    fichier="${fichier_arg:?Fichier à encoder}"
    base64 -w0 "$fichier" 2>/dev/null || base64 "$fichier" | tr -d '\n'
    echo
    ;;
  *)
    sed -n '2,11p' "$0"
    exit 1
    ;;
esac

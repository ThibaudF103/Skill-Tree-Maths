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
    cer="${2:?Chemin du fichier .cer téléchargé chez Apple}"
    openssl x509 -inform DER -in "$cer" -out distribution.pem
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
    fichier="${2:?Fichier à encoder}"
    base64 -w0 "$fichier" 2>/dev/null || base64 "$fichier" | tr -d '\n'
    echo
    ;;
  *)
    sed -n '2,11p' "$0"
    exit 1
    ;;
esac

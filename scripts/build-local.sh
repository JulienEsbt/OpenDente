#!/bin/bash
# Builds and tests locally; never installs or launches the privileged service.
set -euo pipefail

if [[ "$(uname -s)" != Darwin ]]; then
  echo "Ce script nécessite macOS et Xcode. Aucun service n’a été installé." >&2
  exit 1
fi

if [[ $# -lt 1 || -z "$1" || "$1" == "-" ]]; then
  echo 'Usage : bash scripts/build-local.sh "Nom du certificat de signature" [Team ID]' >&2
  echo 'Identités disponibles : security find-identity -v -p codesigning' >&2
  echo 'L’app et son service doivent utiliser le même certificat ; la signature ad hoc est refusée.' >&2
  exit 2
fi

for dependency in xcodebuild xcodegen codesign security; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    echo "Commande manquante : $dependency. Voir README-PERSONAL.md." >&2
    exit 2
  fi
done

# xcodebuild also exists with Command Line Tools alone, but cannot build/test apps.
if ! xcodebuild -version >/dev/null 2>&1; then
  echo 'Xcode complet doit être installé, initialisé et sélectionné. Les Command Line Tools seuls ne suffisent pas.' >&2
  echo 'Ouvrir Xcode pour terminer son installation, puis sélectionner son dossier Developer avec xcode-select ou DEVELOPER_DIR.' >&2
  exit 2
fi

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
signing_identity="$1"
signing_team="${2:-}"
derived_data="$project_root/build/DerivedData"
cd "$project_root"
xcodegen generate --spec project.yml

# XCTest's host skips real services in AppDelegate. The scheme includes the app
# and its helper in the build but does not register the helper with launchd.
xcodebuild test \
  -project OpenDente.xcodeproj \
  -scheme OpenDente \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$derived_data" \
  CODE_SIGN_STYLE=Manual \
  "CODE_SIGN_IDENTITY=$signing_identity" \
  "DEVELOPMENT_TEAM=$signing_team"

app_path="$derived_data/Build/Products/Debug/OpenDente.app"
helper_path="$app_path/Contents/Library/HelperTools/com.opendente.helper"
codesign --verify --strict --verbose=2 "$app_path"
codesign --verify --strict --verbose=2 "$helper_path"

certificate_dir="$(mktemp -d "${TMPDIR:-/tmp}/opendente-certificates.XXXXXX")"
# The trap removes only the private temporary directory created immediately above.
trap 'rm -rf -- "$certificate_dir"' EXIT
codesign -d --extract-certificates "$certificate_dir/app-" "$app_path"
codesign -d --extract-certificates "$certificate_dir/helper-" "$helper_path"
if [[ ! -s "$certificate_dir/app-0" || ! -s "$certificate_dir/helper-0" ]]; then
  echo 'Signature sans certificat : le service refuserait la connexion.' >&2
  exit 3
fi
if ! cmp -s "$certificate_dir/app-0" "$certificate_dir/helper-0"; then
  echo 'Les certificats de l’app et du service sont différents.' >&2
  exit 3
fi

echo "Tests natifs et signatures vérifiés. Application : $app_path"
echo 'Avant utilisation : suivre les essais macOS décrits dans README-PERSONAL.md.'

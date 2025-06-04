#!/bin/bash
# Script pour déployer un package .deb dans un dépôt APT local

set -e  # Arrêter le script en cas d'erreur

REPO_NAME="dodate"
REL_POOL_DIR="pool"
REL_DIST_DIR="dists/stable"
ARCH="all"
COMPONENT="main"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction d'affichage avec couleur
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Vérification des dépendances
check_dependencies() {
    local missing_deps=()

    if ! command -v apt-ftparchive &> /dev/null; then
        missing_deps+=("apt-utils")
    fi

    if ! command -v dpkg-scanpackages &> /dev/null; then
        missing_deps+=("dpkg-dev")
    fi

    if ! command -v gpg &> /dev/null; then
        missing_deps+=("gnupg")
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Dépendances manquantes: ${missing_deps[*]}"
        echo "Installez-les avec: sudo apt install ${missing_deps[*]}"
        exit 3
    fi
}

# Vérification des arguments
if [ $# -lt 2 ]; then
  print_error "Usage: $0 <path/to/package.deb> <GPG_KEY_ID>"
  print_info "Exemple: $0 dodate.deb 82B7DA8E7DDFC3E0D77C6D6C461A393C63B5DF4A"
  exit 1
fi

DEB_FILE="$1"
GPG_KEY_ID="$2"

# Vérification du fichier .deb
if [ ! -f "$DEB_FILE" ]; then
  print_error "Erreur : fichier .deb introuvable : $DEB_FILE"
  exit 2
fi

# Vérification de la clé GPG
if ! gpg --list-secret-keys "$GPG_KEY_ID" &>/dev/null; then
  print_error "Erreur : clé GPG '$GPG_KEY_ID' introuvable dans le trousseau"
  print_info "Listez vos clés avec: gpg --list-secret-keys"
  exit 4
fi

check_dependencies

print_info "🚀 Démarrage du déploiement du dépôt APT..."
print_info "📦 Package: $(basename "$DEB_FILE")"
print_info "🔑 Clé GPG: $GPG_KEY_ID"

mkdir -p "$REPO_NAME"

mkdir -p "$REPO_NAME/$REL_POOL_DIR/$REPO_NAME"
mkdir -p "$REPO_NAME/$REL_DIST_DIR/$COMPONENT/binary-$ARCH"

cp "$DEB_FILE" "$REPO_NAME/$REL_POOL_DIR/$REPO_NAME/"

cd "$REPO_NAME"

# Générer le fichier Packages
apt-ftparchive packages "$REL_POOL_DIR" > "$REL_DIST_DIR/$COMPONENT/binary-$ARCH/Packages"

# Compresser le fichier Packages
gzip -kf "$REL_DIST_DIR/$COMPONENT/binary-$ARCH/Packages"

# Générer le fichier Release
apt-ftparchive \
  -o APT::FTPArchive::Release::Origin="dodate" \
  -o APT::FTPArchive::Release::Label="dodate" \
  -o APT::FTPArchive::Release::Suite="stable" \
  -o APT::FTPArchive::Release::Codename="stable" \
  -o APT::FTPArchive::Release::Architectures="$ARCH" \
  -o APT::FTPArchive::Release::Components="$COMPONENT" \
  release "$REL_DIST_DIR" > "$REL_DIST_DIR/Release"

# Signer le fichier Release
gpg --default-key "$GPG_KEY_ID" --detach-sign -o "$REL_DIST_DIR/Release.gpg" "$REL_DIST_DIR/Release"
gpg --default-key "$GPG_KEY_ID" --clearsign -o "$REL_DIST_DIR/InRelease" "$REL_DIST_DIR/Release"

# Export gpg public key
gpg --export -a "$GPG_KEY_ID" > "public.key"

print_success "Dépôt APT généré avec succès!"
print_info "📁 Structure créée dans : $REPO_NAME/"
print_info "🔑 Clé publique : $REPO_NAME/public.key"
print_info "📦 Package déployé : $(basename "$DEB_FILE")"
echo ""
print_info "Pour déployer sur votre serveur :"
print_info "  rsync -av $REPO_NAME/ user@<your-ip>:/var/www/html/apt/"
echo ""
print_info "Pour utiliser ce dépôt sur un client :"
print_info "  curl -fsSL http://<your-ip>:<port>/apt/public.key | sudo gpg --dearmor -o /usr/share/keyrings/dodate.gpg"
print_info "  echo 'deb [signed-by=/usr/share/keyrings/dodate.gpg] http://<your-ip>:<port>/apt/dodate stable main' | sudo tee /etc/apt/sources.list.d/dodate.list"
print_info "  sudo apt update && sudo apt install dodate"


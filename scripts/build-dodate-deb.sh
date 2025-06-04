#!/bin/bash
# Script pour construire le package .deb de dodate

set -e  # Arrêter le script en cas d'erreur

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="/tmp/dodate-build-$$"
PACKAGE_NAME="dodate"
VERSION="1.0.1"

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

# Fonction de nettoyage
cleanup() {
    if [ -d "$BUILD_DIR" ]; then
        print_info "Nettoyage du répertoire temporaire..."
        rm -rf "$BUILD_DIR"
    fi
}

# Nettoyage en cas d'interruption
trap cleanup EXIT

# Vérification des dépendances
check_dependencies() {
    local missing_deps=()

    if ! command -v dpkg-deb &> /dev/null; then
        missing_deps+=("dpkg-dev")
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Dépendances manquantes: ${missing_deps[*]}"
        echo "Installez-les avec: sudo apt install ${missing_deps[*]}"
        exit 1
    fi
}

print_info "🔨 Construction du package $PACKAGE_NAME v$VERSION..."

check_dependencies

# Créer le répertoire de build temporaire
print_info "📁 Création du répertoire de build..."
mkdir -p "$BUILD_DIR"

# Copier la structure du package
print_info "📋 Copie de la structure du package..."
cp -r "$PROJECT_DIR/dodate" "$BUILD_DIR/"

# Vérifier que l'environnement virtuel existe
if [ -d "$BUILD_DIR/dodate/usr/lib/dodate/dodate_env" ]; then
    print_success "Environnement virtuel trouvé dans le package"
else
    print_warning "Aucun environnement virtuel trouvé - package sans dépendances Python"
fi

# Mettre à jour les permissions
print_info "🔐 Configuration des permissions..."
chmod +x "$BUILD_DIR/dodate/DEBIAN/postinst"
chmod +x "$BUILD_DIR/dodate/DEBIAN/prerm"
chmod +x "$BUILD_DIR/dodate/usr/lib/dodate/dodate.py"

# Construire le package
print_info "🏗️  Construction du package .deb..."
cd "$BUILD_DIR"
dpkg-deb --build dodate

# Copier le package dans le répertoire de sortie
OUTPUT_FILE="$PROJECT_DIR/${PACKAGE_NAME}_${VERSION}_all.deb"
cp "$BUILD_DIR/dodate.deb" "$OUTPUT_FILE"

# Définir les bonnes permissions pour APT
chmod 644 "$OUTPUT_FILE"
chown $USER:$USER "$OUTPUT_FILE"

print_success "Package construit avec succès!"
print_info "📦 Package disponible : $OUTPUT_FILE"

# Afficher les informations du package
print_info "📋 Informations du package :"
dpkg-deb --info "$OUTPUT_FILE"

echo ""
print_info "🚀 Pour déployer le package :"
print_info "  ./scripts/apache2-auto-deploy.sh $OUTPUT_FILE <GPG_KEY_ID>"

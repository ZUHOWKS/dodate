#!/bin/bash
# Script pour déployer automatiquement le repository APT sur Apache2

set -e  # Arrêter le script en cas d'erreur

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WEB_ROOT="/var/www/html"
APT_REPO_DIR="$WEB_ROOT/apt"
BUILD_DIR="/tmp/dodate-repo-build-$$"

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

# Vérification des privilèges root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Ce script doit être exécuté avec les privilèges root (sudo)"
        exit 1
    fi
}

# Vérification des dépendances
check_dependencies() {
    local missing_deps=()

    if ! command -v apache2 &> /dev/null; then
        missing_deps+=("apache2")
    fi

    if ! systemctl is-active --quiet apache2; then
        print_warning "Apache2 n'est pas en cours d'exécution"
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Dépendances manquantes: ${missing_deps[*]}"
        echo "Installez-les avec: sudo apt install ${missing_deps[*]}"
        exit 1
    fi
}

# Vérification des arguments
if [ $# -lt 1 ]; then
    print_error "Usage: $0 <GPG_KEY_ID> [package.deb] [port]"
    print_info "Si aucun package n'est spécifié, le script construira automatiquement le package"
    print_info "Si aucun port n'est spécifié, le port 8000 sera utilisé par défaut"
    print_info "Exemple: $0 82B7DA8E7DDFC3E0D77C6D6C461A393C63B5DF4A"
    print_info "Exemple: $0 82B7DA8E7DDFC3E0D77C6D6C461A393C63B5DF4A dodate.deb 9000"
    exit 1
fi

GPG_KEY_ID="$1"
DEB_FILE="$2"
APT_PORT="${3:-8000}"  # Port par défaut: 8000

# Vérification de la clé GPG
if ! gpg --list-secret-keys "$GPG_KEY_ID" &>/dev/null; then
    print_error "Erreur : clé GPG '$GPG_KEY_ID' introuvable dans le trousseau"
    print_info "Listez vos clés avec: gpg --list-secret-keys"
    exit 2
fi

check_root
check_dependencies

print_info "🚀 Déploiement automatique du repository APT dodate..."

# Construire le package si non fourni
if [ -z "$DEB_FILE" ]; then
    print_info "📦 Construction du package .deb..."
    cd "$PROJECT_DIR"
    sudo -u $SUDO_USER ./scripts/build-dodate-deb.sh
    DEB_FILE="$PROJECT_DIR/dodate_1.0.1_all.deb"
fi

# Vérifier que le package existe
if [ ! -f "$DEB_FILE" ]; then
    print_error "Package .deb introuvable: $DEB_FILE"
    exit 3
fi

# Créer le répertoire de build temporaire
print_info "📁 Création du répertoire temporaire..."
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Générer le repository APT
print_info "🏗️  Génération du repository APT..."
sudo -u $SUDO_USER "$SCRIPT_DIR/deploy-apt-repositery.sh" "$DEB_FILE" "$GPG_KEY_ID" --quiet

# Sauvegarder l'ancien repository si il existe
if [ -d "$APT_REPO_DIR" ]; then
    print_info "💾 Sauvegarde de l'ancien repository..."
    mv "$APT_REPO_DIR" "$APT_REPO_DIR.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Créer le répertoire APT dans le web root
print_info "📁 Création du répertoire APT..."
mkdir -p "$APT_REPO_DIR"

# Copier le repository généré
print_info "📋 Copie du repository vers Apache..."
cp -r dodate/* "$APT_REPO_DIR/"

# Configurer les permissions pour Apache
print_info "🔐 Configuration des permissions Apache..."
chown -R www-data:www-data "$APT_REPO_DIR"
chmod -R 755 "$APT_REPO_DIR"

# Créer/Mettre à jour la configuration Apache si nécessaire
APACHE_CONF="/etc/apache2/sites-available/apt-repo-${APT_PORT}.conf"
if [ ! -f "$APACHE_CONF" ]; then
    print_info "⚙️  Création de la configuration Apache pour le port $APT_PORT..."
    cat > "$APACHE_CONF" << EOF
<VirtualHost *:$APT_PORT>
    DocumentRoot /var/www/html
    ServerName localhost

    <Directory /var/www/html/apt>
        Options Indexes FollowSymLinks
        AllowOverride None
        Require all granted

        # Headers pour les fichiers APT
        <FilesMatch "\.(deb|gz|gpg)$">
            Header set Cache-Control "public, max-age=3600"
        </FilesMatch>

        # Type MIME pour les fichiers .deb
        <FilesMatch "\.deb$">
            Header set Content-Type "application/vnd.debian.binary-package"
        </FilesMatch>
    </Directory>

    # Logs spécifiques au repository
    ErrorLog \${APACHE_LOG_DIR}/apt-repo-${APT_PORT}_error.log
    CustomLog \${APACHE_LOG_DIR}/apt-repo-${APT_PORT}_access.log combined
</VirtualHost>
EOF

    # Ajouter le port s'il n'existe pas
    if ! grep -q "Listen $APT_PORT" /etc/apache2/ports.conf; then
        echo "Listen $APT_PORT" >> /etc/apache2/ports.conf
        print_info "✅ Port $APT_PORT ajouté à la configuration Apache"
    fi

    # Activer les modules nécessaires
    a2enmod headers 2>/dev/null || true
    a2enmod dir 2>/dev/null || true

    # Activer le site
    a2ensite apt-repo-${APT_PORT}.conf
    print_info "✅ Site Apache configuré pour le port $APT_PORT"
fi

# Redémarrer Apache2
print_info "🔄 Redémarrage d'Apache2..."
systemctl restart apache2

# Vérifier le statut d'Apache2
if systemctl is-active --quiet apache2; then
    print_success "Apache2 redémarré avec succès!"
else
    print_error "Erreur lors du redémarrage d'Apache2"
    systemctl status apache2
    exit 4
fi

# Afficher les informations de déploiement
print_success "🎉 Repository APT déployé avec succès!"
echo ""
print_info "📊 Informations de déploiement :"
print_info "  🌐 URL du repository : http://localhost:$APT_PORT/apt/"
print_info "  🔑 Clé publique : http://localhost:$APT_PORT/apt/public.key"
print_info "  📦 Package déployé : $(basename "$DEB_FILE")"
print_info "  🚪 Port configuré : $APT_PORT"
echo ""
print_info "🔧 Pour configurer un client :"
print_info "  curl -fsSL http://$(hostname -I | awk '{print $1}'):$APT_PORT/apt/public.key | sudo gpg --dearmor -o /usr/share/keyrings/dodate.gpg"
print_info "  echo 'deb [signed-by=/usr/share/keyrings/dodate.gpg] http://$(hostname -I | awk '{print $1}'):$APT_PORT/apt/dodate stable main' | sudo tee /etc/apt/sources.list.d/dodate.list"
print_info "  sudo apt update && sudo apt install dodate"
echo ""
print_info "📋 Test du repository :"
print_info "  curl -I http://localhost:$APT_PORT/apt/"
print_info "  curl -I http://localhost:$APT_PORT/apt/public.key"

#!/bin/bash
# Script pour désinstaller proprement le repository APT dodate

set -e  # Arrêter le script en cas d'erreur

# Configuration
WEB_ROOT="/var/www/html"
APT_REPO_DIR="$WEB_ROOT/apt"
APACHE_SITES_DIR="/etc/apache2/sites-available"
APACHE_ENABLED_DIR="/etc/apache2/sites-enabled"
PORTS_CONF="/etc/apache2/ports.conf"

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

# Fonction de confirmation
confirm() {
    read -p "$(echo -e "${YELLOW}⚠️  $1 [y/N]: ${NC}")" -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# Vérification des privilèges root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Ce script doit être exécuté avec les privilèges root (sudo)"
        exit 1
    fi
}

# Fonction pour trouver et supprimer les sites Apache liés au repository
remove_apache_sites() {
    local sites_found=0
    
    print_info "🔍 Recherche des sites Apache pour le repository dodate..."
    
    # Chercher tous les fichiers de configuration apt-repo-*
    for conf_file in "$APACHE_SITES_DIR"/apt-repo-*.conf; do
        if [ -f "$conf_file" ]; then
            sites_found=$((sites_found + 1))
            local site_name=$(basename "$conf_file")
            local port=$(echo "$site_name" | sed 's/apt-repo-\([0-9]*\)\.conf/\1/')
            
            print_info "📋 Site trouvé : $site_name (port $port)"
            
            if confirm "Supprimer le site $site_name ?"; then
                # Désactiver le site s'il est activé
                if [ -L "$APACHE_ENABLED_DIR/$site_name" ]; then
                    print_info "🔄 Désactivation du site $site_name..."
                    a2dissite "$site_name" 2>/dev/null || true
                fi
                
                # Supprimer le fichier de configuration
                print_info "🗑️  Suppression de $conf_file..."
                rm -f "$conf_file"
                
                # Supprimer le port du fichier ports.conf si nécessaire
                if [ -n "$port" ] && grep -q "Listen $port" "$PORTS_CONF"; then
                    if confirm "Supprimer le port $port de la configuration Apache ?"; then
                        print_info "🚪 Suppression du port $port..."
                        sed -i "/^Listen $port$/d" "$PORTS_CONF"
                    fi
                fi
                
                print_success "Site $site_name supprimé"
            fi
        fi
    done
    
    if [ $sites_found -eq 0 ]; then
        print_info "Aucun site Apache trouvé pour le repository dodate"
    fi
}

# Fonction pour supprimer le repository APT
remove_apt_repository() {
    if [ -d "$APT_REPO_DIR" ]; then
        print_info "📁 Repository APT trouvé : $APT_REPO_DIR"
        
        # Afficher la taille du repository
        local repo_size=$(du -sh "$APT_REPO_DIR" 2>/dev/null | cut -f1 || echo "inconnu")
        print_info "📊 Taille du repository : $repo_size"
        
        # Afficher le contenu
        print_info "📋 Contenu du repository :"
        ls -la "$APT_REPO_DIR" 2>/dev/null || true
        
        if confirm "Supprimer complètement le repository APT ($APT_REPO_DIR) ?"; then
            # Créer une sauvegarde si demandé
            if confirm "Créer une sauvegarde avant suppression ?"; then
                local backup_dir="/tmp/dodate-apt-backup-$(date +%Y%m%d_%H%M%S)"
                print_info "💾 Création de la sauvegarde : $backup_dir"
                cp -r "$APT_REPO_DIR" "$backup_dir"
                print_success "Sauvegarde créée : $backup_dir"
            fi
            
            print_info "🗑️  Suppression du repository APT..."
            rm -rf "$APT_REPO_DIR"
            print_success "Repository APT supprimé"
        else
            print_info "Repository APT conservé"
        fi
    else
        print_info "Aucun repository APT trouvé dans $APT_REPO_DIR"
    fi
}

# Fonction pour nettoyer les sources APT sur les clients
show_client_cleanup_instructions() {
    print_info "📋 Instructions pour nettoyer les clients :"
    echo ""
    print_info "Sur chaque machine cliente ayant utilisé ce repository, exécutez :"
    echo -e "${BLUE}  # Supprimer la source APT${NC}"
    echo -e "${BLUE}  sudo rm -f /etc/apt/sources.list.d/dodate.list${NC}"
    echo ""
    echo -e "${BLUE}  # Supprimer la clé GPG${NC}"
    echo -e "${BLUE}  sudo rm -f /usr/share/keyrings/dodate.gpg${NC}"
    echo ""
    echo -e "${BLUE}  # Désinstaller le package dodate${NC}"
    echo -e "${BLUE}  sudo apt remove --purge dodate${NC}"
    echo ""
    echo -e "${BLUE}  # Mettre à jour les sources${NC}"
    echo -e "${BLUE}  sudo apt update${NC}"
    echo ""
}

# Fonction pour vérifier l'état d'Apache
check_apache_status() {
    if systemctl is-active --quiet apache2; then
        print_info "✅ Apache2 est en cours d'exécution"
        
        if confirm "Recharger la configuration Apache2 ?"; then
            print_info "🔄 Rechargement de la configuration Apache2..."
            systemctl reload apache2
            print_success "Configuration Apache2 rechargée"
        fi
    else
        print_warning "Apache2 n'est pas en cours d'exécution"
    fi
}

# Fonction principale
main() {
    print_info "🧹 Désinstallation du repository APT dodate"
    echo ""
    
    check_root
    
    # Afficher un résumé de ce qui sera supprimé
    print_info "🔍 Analyse du système..."
    
    local items_to_remove=()
    
    if [ -d "$APT_REPO_DIR" ]; then
        items_to_remove+=("Repository APT ($APT_REPO_DIR)")
    fi
    
    for conf_file in "$APACHE_SITES_DIR"/apt-repo-*.conf; do
        if [ -f "$conf_file" ]; then
            items_to_remove+=("Configuration Apache : $(basename "$conf_file")")
        fi
    done
    
    if [ ${#items_to_remove[@]} -eq 0 ]; then
        print_info "Aucun élément du repository dodate trouvé sur le système"
        exit 0
    fi
    
    echo ""
    print_info "📋 Éléments détectés à supprimer :"
    for item in "${items_to_remove[@]}"; do
        echo -e "  ${YELLOW}• $item${NC}"
    done
    echo ""
    
    if ! confirm "Continuer avec la désinstallation ?"; then
        print_info "Désinstallation annulée"
        exit 0
    fi
    
    echo ""
    print_info "🚀 Début de la désinstallation..."
    
    # Supprimer les sites Apache
    remove_apache_sites
    
    echo ""
    
    # Supprimer le repository APT
    remove_apt_repository
    
    echo ""
    
    # Vérifier et recharger Apache
    check_apache_status
    
    echo ""
    
    # Afficher les instructions de nettoyage client
    show_client_cleanup_instructions
    
    print_success "🎉 Désinstallation terminée avec succès !"
    print_info "Apache2 est toujours installé et configuré pour d'autres usages"
}

# Vérification des arguments
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0 [--force]"
    echo ""
    echo "Désinstalle proprement le repository APT dodate et sa configuration Apache"
    echo ""
    echo "Options:"
    echo "  --force    Supprime tout sans demander de confirmation"
    echo "  --help     Affiche cette aide"
    echo ""
    echo "Ce script supprime :"
    echo "  • Le repository APT (/var/www/html/apt)"
    echo "  • Les configurations Apache (apt-repo-*.conf)"
    echo "  • Les ports associés dans ports.conf"
    echo ""
    echo "Ce script NE supprime PAS :"
    echo "  • Apache2 lui-même"
    echo "  • Les autres sites Apache"
    echo "  • Les configurations Apache non liées au repository"
    exit 0
fi

# Mode force (sans confirmation)
if [ "$1" = "--force" ]; then
    confirm() { return 0; }
    print_warning "Mode force activé - suppression sans confirmation"
fi

# Exécuter le script principal
main
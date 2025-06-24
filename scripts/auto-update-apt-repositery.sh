#!/bin/bash
# Auto-update script for APT repository
# This script regenerates the Packages and Release files when new packages are detected
# Designed to be run as a cron job

set -e  # Stop script on error

# Configuration
WEB_ROOT="/var/www/html"
APT_REPO_DIR="$WEB_ROOT/apt"
POOL_DIR="$APT_REPO_DIR/pool/main/dodate"
DIST_DIR="$APT_REPO_DIR/dists/dodate"
BINARY_DIR="$DIST_DIR/main/binary-all"
LOG_FILE="/var/log/apt-repo-update.log"
COMPONENT="main"
ARCH="all"

# Lock file to prevent concurrent executions
LOCK_FILE="/tmp/apt-repo-update.lock"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_info() {
    log "ℹ️  $1"
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    log "✅ $1"
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    log "⚠️  $1"
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    log "❌ $1"
    echo -e "${RED}❌ $1${NC}"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root (sudo)"
        exit 1
    fi
}

# Acquire lock to prevent concurrent executions
acquire_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local lock_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
        if [ -n "$lock_pid" ] && kill -0 "$lock_pid" 2>/dev/null; then
            log_warning "Another instance is already running (PID: $lock_pid)"
            exit 0
        else
            log_info "Removing stale lock file"
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
}

# Release lock
release_lock() {
    rm -f "$LOCK_FILE"
}

# Cleanup function
cleanup() {
    release_lock
}

# Set trap for cleanup
trap cleanup EXIT

# Check if repository structure exists
check_repository_structure() {
    if [ ! -d "$APT_REPO_DIR" ]; then
        log_error "APT repository directory not found: $APT_REPO_DIR"
        exit 1
    fi

    if [ ! -d "$POOL_DIR" ]; then
        log_warning "Pool directory not found: $POOL_DIR"
        log_info "Creating pool directory structure..."
        mkdir -p "$POOL_DIR"
        chown -R www-data:www-data "$POOL_DIR"
        chmod -R 755 "$POOL_DIR"
    fi

    if [ ! -d "$BINARY_DIR" ]; then
        log_info "Creating binary directory structure..."
        mkdir -p "$BINARY_DIR"
        chown -R www-data:www-data "$DIST_DIR"
        chmod -R 755 "$DIST_DIR"
    fi
}

# Check for GPG key configuration
check_gpg_key() {
    # Try to find the GPG key used for signing
    if [ -f "$APT_REPO_DIR/public.key" ]; then
        # Extract key ID from the public key file
        GPG_KEY_ID=$(gpg --with-colons --import-options show-only --import "$APT_REPO_DIR/public.key" 2>/dev/null | grep '^pub:' | cut -d: -f5 | tail -1)
        if [ -n "$GPG_KEY_ID" ]; then
            log_info "Using GPG key: $GPG_KEY_ID"
            return 0
        fi
    fi

    # Fallback: try to find any available secret key
    GPG_KEY_ID=$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null | grep '^sec' | head -1 | sed 's/.*\/\([A-F0-9]*\).*/\1/')
    if [ -n "$GPG_KEY_ID" ]; then
        log_warning "Using first available GPG key: $GPG_KEY_ID"
        return 0
    fi

    log_error "No GPG key found for signing. Repository will not be signed."
    return 1
}

# Get the modification time of the newest package in the pool
get_newest_package_time() {
    find "$POOL_DIR" -name "*.deb" -exec stat -c %Y {} \; 2>/dev/null | sort -n | tail -1
}

# Get the modification time of the Packages file
get_packages_file_time() {
    if [ -f "$BINARY_DIR/Packages" ]; then
        stat -c %Y "$BINARY_DIR/Packages" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Check if update is needed
needs_update() {
    local newest_package_time=$(get_newest_package_time)
    local packages_file_time=$(get_packages_file_time)

    # If no packages found, no update needed
    if [ -z "$newest_package_time" ]; then
        log_info "No packages found in pool directory"
        return 1
    fi

    # If Packages file doesn't exist or is older than newest package
    if [ "$packages_file_time" -lt "$newest_package_time" ]; then
        log_info "Update needed: newest package is newer than Packages file"
        return 0
    fi

    log_info "No update needed: Packages file is up to date"
    return 1
}

# Generate Packages file
generate_packages() {
    log_info "Generating Packages file..."

    # Check if there are any .deb files
    if ! ls "$POOL_DIR"/*.deb >/dev/null 2>&1; then
        log_warning "No .deb packages found in $POOL_DIR"
        # Create empty Packages file
        touch "$BINARY_DIR/Packages"
        gzip -c "$BINARY_DIR/Packages" > "$BINARY_DIR/Packages.gz"
        return 0
    fi

    # Generate Packages file using dpkg-scanpackages
    cd "$APT_REPO_DIR"
    dpkg-scanpackages pool/main/dodate /dev/null > "$BINARY_DIR/Packages" 2>/dev/null

    # Compress Packages file
    gzip -c "$BINARY_DIR/Packages" > "$BINARY_DIR/Packages.gz"

    log_success "Packages file generated successfully"
}

# Generate Release file
generate_release() {
    log_info "Generating Release file..."

    # Create Release file using apt-ftparchive
    cd "$DIST_DIR"

    # Create a temporary configuration file for apt-ftparchive
    local config_file="/tmp/apt-ftparchive-$$.conf"
    cat > "$config_file" << EOF
Dir {
    ArchiveDir "$APT_REPO_DIR";
};

TreeDefault {
    Directory "pool/main/dodate";
};

Tree "dists/dodate" {
    Sections "$COMPONENT";
    Architectures "$ARCH";
    BinOverride "override.dodate.$COMPONENT";
    BinCacheDB "packages-$COMPONENT-$ARCH.db";
};

Default {
    Packages::Compress ". gzip";
};
EOF

    # Create empty override file if it doesn't exist
    touch "$DIST_DIR/override.dodate.$COMPONENT"

    # Generate Release file
    apt-ftparchive release -c "$config_file" . > Release

    # Cleanup
    rm -f "$config_file"

    log_success "Release file generated successfully"
}

# Sign Release file with GPG
sign_release() {
    if ! check_gpg_key; then
        log_warning "Skipping GPG signing - no key available"
        return 0
    fi

    log_info "Signing Release file with GPG..."

    cd "$DIST_DIR"

    # Sign Release file
    gpg --default-key "$GPG_KEY_ID" --clearsign -o InRelease Release 2>/dev/null
    gpg --default-key "$GPG_KEY_ID" -abs -o Release.gpg Release 2>/dev/null

    log_success "Release file signed successfully"
}

# Set correct permissions
fix_permissions() {
    log_info "Setting correct permissions..."

    chown -R www-data:www-data "$APT_REPO_DIR"
    chmod -R 755 "$APT_REPO_DIR"

    # Make sure .deb files are readable
    find "$POOL_DIR" -name "*.deb" -exec chmod 644 {} \;

    log_success "Permissions set correctly"
}

# Main function
main() {
    log_info "Starting APT repository auto-update"
    log_info "Repository: $APT_REPO_DIR"
    log_info "Pool: $POOL_DIR"

    check_root
    acquire_lock
    check_repository_structure

    # Check if update is needed
    if ! needs_update; then
        log_info "Repository is up to date"
        exit 0
    fi

    # Perform update
    log_info "Starting repository update..."

    generate_packages
    generate_release
    sign_release
    fix_permissions

    log_success "Repository update completed successfully"

    # Show summary
    local package_count=$(ls "$POOL_DIR"/*.deb 2>/dev/null | wc -l)
    log_info "Repository summary:"
    log_info "  - Packages in pool: $package_count"
    log_info "  - Packages file: $BINARY_DIR/Packages"
    log_info "  - Release file: $DIST_DIR/Release"
    if [ -f "$DIST_DIR/InRelease" ]; then
        log_info "  - Signed: Yes (InRelease, Release.gpg)"
    else
        log_info "  - Signed: No"
    fi
}

# Show usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Auto-update script for APT repository"
    echo ""
    echo "Options:"
    echo "  --force     Force update even if not needed"
    echo "  --help      Show this help message"
    echo ""
    echo "This script is designed to be run as a cron job to automatically"
    echo "update the APT repository when new packages are added to the pool."
    echo ""
    echo "Example cron job (run every 5 minutes):"
    echo "*/5 * * * * /home/joris/dev/projects/dodate/scripts/auto-update-apt-repositery.sh >/dev/null 2>&1"
}

# Handle command line arguments
case "${1:-}" in
    --force)
        # Override needs_update function to always return true
        needs_update() { return 0; }
        log_info "Force update mode enabled"
        ;;
    --help|-h)
        usage
        exit 0
        ;;
    "")
        # Normal operation
        ;;
    *)
        echo "Unknown option: $1"
        usage
        exit 1
        ;;
esac

# Run main function
main

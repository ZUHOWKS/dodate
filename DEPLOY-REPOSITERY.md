# 🚀 Dodate APT Repository Deployment Guide

This guide explains how to automatically deploy an APT repository for the `dodate` package using the provided scripts.

---

## 📋 Prerequisites

### 1. System dependencies

```bash
# Install required tools
sudo apt update
sudo apt install -y \
    dpkg-dev \
    apt-utils \
    gnupg2 \
    apache2
```

### 2. GPG Key

You must have a GPG key to sign the repository:

```bash
# Generate a new GPG key (if needed)
gpg --gen-key

# List your keys to get the ID
gpg --list-secret-keys --keyid-format LONG

# Note your key's ID (format: XXXXXXXXXXXXXXXX)
```

---

## 🛠️ Available scripts

### 1. `build-dodate-deb.sh`

Builds the `.deb` package with the integrated Python virtual environment.

### 2. `deploy-apt-repositery.sh`

Generates a local APT repository with GPG signature.

### 3. `apache2-auto-deploy.sh`

Main automatic deployment script that:

- Builds the package (if needed)
- Generates the APT repository
- Configures Apache2
- Deploys the repository

---

## 🚀 Quick deployment

### Method 1: Full automatic deployment

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Deploy with automatic package build
sudo ./scripts/apache2-auto-deploy.sh YOUR_GPG_KEY_ID

# Example with your GPG key
sudo ./scripts/apache2-auto-deploy.sh 82B7DA8E7DDFC3E0D77C6D6C461A393C63B5DF4A
```

### Method 2: Deployment with an existing package

```bash
# If you already have a .deb package
sudo ./scripts/apache2-auto-deploy.sh YOUR_GPG_KEY_ID path/to/dodate.deb

# Example
sudo ./scripts/apache2-auto-deploy.sh 82B7DA8E7DDFC3E0D77C6D6C461A393C63B5DF4A dodate_1.0.1_all.deb
```

### Method 3: Deployment on a custom port

```bash
# Deploy on port 9000 instead of the default 8000
sudo ./scripts/apache2-auto-deploy.sh YOUR_GPG_KEY_ID "" 9000

# Or with an existing package on port 3000
sudo ./scripts/apache2-auto-deploy.sh YOUR_GPG_KEY_ID dodate.deb 3000
```

---

## 📊 What happens automatically

### 1. Package build

- Creation of a Python virtual environment
- Installation of `pytz` in the virtual environment
- Building the `.deb` package

### 2. Repository generation

- Standard Debian structure (`dists/`, `pool/`)
- Generation of `Packages`, `Release` files
- GPG signature (`Release.gpg`, `InRelease`)
- Export of the public key

### 3. Apache configuration

- Creation of the VirtualHost on the specified port
- Permission configuration
- Activation of required modules
- Apache2 restart

---

## 🌐 Repository access

After deployment, your repository will be accessible at:

- **Main URL**: `http://your-server:PORT/apt/`
- **Public key**: `http://your-server:PORT/apt/public.key`
- **Packages**: `http://your-server:PORT/apt/dodate/main/binary-all/`

**Default port**: 8000

---

## 💻 Client configuration

### 1. Add the GPG key

```bash
# Download and install the public key
curl -fsSL http://YOUR-SERVER:PORT/apt/public.key | sudo gpg --dearmor -o /usr/share/keyrings/dodate.gpg
```

### 2. Add the repository

```bash
# Add the repository to your APT sources
echo 'deb [signed-by=/usr/share/keyrings/dodate.gpg] http://YOUR-SERVER:PORT/apt dodate main' | sudo tee /etc/apt/sources.list.d/dodate.list
```

### 3. Install the package

```bash
# Update and install
sudo apt update
sudo apt install dodate
```

### Full example

```bash
# For a server at 192.168.1.100 port 8000
curl -fsSL http://192.168.1.100:8000/apt/public.key | sudo gpg --dearmor -o /usr/share/keyrings/dodate.gpg
echo 'deb [signed-by=/usr/share/keyrings/dodate.gpg] http://192.168.1.100:8000/apt/dodate main' | sudo tee /etc/apt/sources.list.d/dodate.list
sudo apt update
sudo apt install dodate
```

---

## 🔧 Manual step-by-step deployment

If you prefer to control each step:

### 1. Build the package

```bash
./scripts/build-dodate-deb.sh
```

### 2. Generate the repository

```bash
./scripts/deploy-apt-repositery.sh dodate_1.0.1_all.deb YOUR_GPG_KEY_ID
```

### 3. Manual deployment

```bash
# Copy to Apache
sudo cp -r dodate/* /var/www/html/apt/
sudo chown -R www-data:www-data /var/www/html/apt/
sudo chmod -R 755 /var/www/html/apt/

# Configure Apache (see configuration below)
```

---

## ⚙️ Manual Apache configuration

If you want to configure Apache manually:

### 1. Create the VirtualHost

```bash
sudo nano /etc/apache2/sites-available/apt-repo-8000.conf
```

```apache
<VirtualHost *:8000>
    DocumentRoot /var/www/html
    ServerName localhost

    <Directory /var/www/html/apt>
        Options Indexes FollowSymLinks
        AllowOverride None
        Require all granted

        # Headers for APT files
        <FilesMatch "\.(deb|gz|gpg)$">
            Header set Cache-Control "public, max-age=3600"
        </FilesMatch>

        # MIME type for .deb files
        <FilesMatch "\.deb$">
            Header set Content-Type "application/vnd.debian.binary-package"
        </FilesMatch>
    </Directory>

    # Repository-specific logs
    ErrorLog ${APACHE_LOG_DIR}/apt-repo-8000_error.log
    CustomLog ${APACHE_LOG_DIR}/apt-repo-8000_access.log combined
</VirtualHost>
```

### 2. Enable the configuration

```bash
# Add the port
echo "Listen 8000" | sudo tee -a /etc/apache2/ports.conf

# Enable modules
sudo a2enmod headers
sudo a2enmod dir

# Enable the site
sudo a2ensite apt-repo-8000.conf

# Restart Apache
sudo systemctl restart apache2
```

---

## 🔍 Verification and tests

### 1. Check Apache

```bash
# Apache status
sudo systemctl status apache2

# Check listening ports
sudo netstat -tlnp | grep apache2
```

### 2. Test the repository

```bash
# Test HTTP access
curl -I http://localhost:8000/apt/

# Test the public key
curl -I http://localhost:8000/apt/public.key

# Test the packages
curl -I http://localhost:8000/apt/dodate/main/binary-all/Packages.gz
```

### 3. Test installation

```bash
# On a client machine
curl -fsSL http://YOUR-IP:8000/apt/public.key | sudo gpg --dearmor -o /usr/share/keyrings/dodate.gpg
echo 'deb [signed-by=/usr/share/keyrings/dodate.gpg] http://YOUR-IP:8000/apt dodate main' | sudo tee /etc/apt/sources.list.d/dodate.list
sudo apt update
apt list dodate
sudo apt install dodate
dodate
```

---

## 🚨 Troubleshooting

### Common issues

#### 1. Permission error on the .deb file

```bash
# If you get the error "_apt couldn't be accessed by user"
sudo chmod 644 package.deb
sudo chown root:root package.deb

# Or install from the repository instead of the local file
sudo apt remove --purge dodate
sudo apt update
sudo apt install dodate
```

#### 2. Repository permission error

```bash
sudo chown -R www-data:www-data /var/www/html/apt/
sudo chmod -R 755 /var/www/html/apt/
```

#### 2. Apache does not start

```bash
# Check the configuration
sudo apache2ctl configtest

# View error logs
sudo tail -f /var/log/apache2/error.log
```

#### 3. GPG key not recognized

```bash
# Check that the key exists
gpg --list-secret-keys

# Regenerate the public key
gpg --export -a YOUR_GPG_KEY_ID > /var/www/html/apt/public.key
```

#### 4. Port already in use

```bash
# Check which process uses the port
sudo netstat -tlnp | grep :8000

# Use another port
sudo ./scripts/apache2-auto-deploy.sh YOUR_GPG_KEY_ID "" 9000
```

---

## 🔄 Repository update

To add a new version of your package:

```bash
# Build the new version
./scripts/build-dodate-deb.sh

# Redeploy automatically
sudo ./scripts/apache2-auto-deploy.sh YOUR_GPG_KEY_ID dodate_1.0.2_all.deb

# Or manually
./scripts/deploy-apt-repositery.sh dodate_1.0.2_all.deb YOUR_GPG_KEY_ID
sudo cp -r dodate/* /var/www/html/apt/
```

---

## 📝 Final repository structure

```
/var/www/html/apt/
├── dodate/
│   ├── dists/
│   │   └── dodate/
│   │       ├── main/
│   │       │   └── binary-all/
│   │       │       ├── Packages
│   │       │       └── Packages.gz
│   │       ├── Release
│   │       ├── Release.gpg
│   │       └── InRelease
│   └── pool/
│       └── dodate/
│           └── dodate_1.0.1_all.deb
└── public.key
```

---

## 🎯 Quick reference commands

```bash
# Full automatic deployment
sudo ./scripts/apache2-auto-deploy.sh GPG_KEY_ID

# With custom port
sudo ./scripts/apache2-auto-deploy.sh GPG_KEY_ID "" 9000

# Build only
./scripts/build-dodate-deb.sh

# Repository only
./scripts/deploy-apt-repositery.sh package.deb GPG_KEY_ID

# Client test
curl -fsSL http://IP:PORT/apt/public.key | sudo gpg --dearmor -o /usr/share/keyrings/dodate.gpg
echo 'deb [signed-by=/usr/share/keyrings/dodate.gpg] http://IP:PORT/apt dodate main' | sudo tee /etc/apt/sources.list.d/dodate.list
sudo apt update && sudo apt install dodate
```

---

**🎉 Your Dodate APT repository is now ready and accessible!**

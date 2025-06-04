# 🚀 Guide de déploiement du repository APT Dodate

Ce guide explique comment déployer automatiquement un repository APT pour le package `dodate` en utilisant les scripts fournis.

---

## 📋 Prérequis

### 1. Dépendances système

```bash
# Installer les outils nécessaires
sudo apt update
sudo apt install -y \
    dpkg-dev \
    apt-utils \
    gnupg2 \
    apache2 \
    python3 \
    python3-venv \
    curl
```

### 2. Clé GPG

Vous devez avoir une clé GPG pour signer le repository :

```bash
# Générer une nouvelle clé GPG (si nécessaire)
gpg --gen-key

# Lister vos clés pour obtenir l'ID
gpg --list-secret-keys --keyid-format LONG

# Noter l'ID de votre clé (format: XXXXXXXXXXXXXXXX)
```

---

## 🛠️ Scripts disponibles

### 1. `build-dodate-deb.sh`

Construit le package `.deb` avec l'environnement virtuel Python intégré.

### 2. `deploy-apt-repositery.sh`

Génère un repository APT local avec signature GPG.

### 3. `apache2-auto-deploy.sh`

Script principal de déploiement automatique qui :

- Construit le package (si nécessaire)
- Génère le repository APT
- Configure Apache2
- Déploie le repository

---

## 🚀 Déploiement rapide

### Méthode 1 : Déploiement automatique complet

```bash
# Rendre les scripts exécutables
chmod +x scripts/*.sh

# Déploiement avec construction automatique du package
sudo ./scripts/apache2-auto-deploy.sh VOTRE_GPG_KEY_ID

# Exemple avec votre clé GPG
sudo ./scripts/apache2-auto-deploy.sh 82B7DA8E7DDFC3E0D77C6D6C461A393C63B5DF4A
```

### Méthode 2 : Déploiement avec package existant

```bash
# Si vous avez déjà un package .deb
sudo ./scripts/apache2-auto-deploy.sh VOTRE_GPG_KEY_ID chemin/vers/dodate.deb

# Exemple
sudo ./scripts/apache2-auto-deploy.sh 82B7DA8E7DDFC3E0D77C6D6C461A393C63B5DF4A dodate_1.0.1_all.deb
```

### Méthode 3 : Déploiement sur un port personnalisé

```bash
# Déployer sur le port 9000 au lieu du port 8000 par défaut
sudo ./scripts/apache2-auto-deploy.sh VOTRE_GPG_KEY_ID "" 9000

# Ou avec un package existant sur le port 3000
sudo ./scripts/apache2-auto-deploy.sh VOTRE_GPG_KEY_ID dodate.deb 3000
```

---

## 📊 Ce qui se passe automatiquement

### 1. Construction du package

- Création d'un environnement virtuel Python
- Installation de `pytz` dans l'environnement virtuel
- Construction du package `.deb`

### 2. Génération du repository

- Structure Debian standard (`dists/`, `pool/`)
- Génération des fichiers `Packages`, `Release`
- Signature GPG (`Release.gpg`, `InRelease`)
- Export de la clé publique

### 3. Configuration Apache

- Création du VirtualHost sur le port spécifié
- Configuration des permissions
- Activation des modules nécessaires
- Redémarrage d'Apache2

---

## 🌐 Accès au repository

Après déploiement, votre repository sera accessible à :

- **URL principale** : `http://votre-serveur:PORT/apt/`
- **Clé publique** : `http://votre-serveur:PORT/apt/public.key`
- **Packages** : `http://votre-serveur:PORT/apt/dodate/stable/main/binary-all/`

**Port par défaut** : 8000

---

## 💻 Configuration d'un client

### 1. Ajouter la clé GPG

```bash
# Télécharger et installer la clé publique
curl -fsSL http://VOTRE-SERVEUR:PORT/apt/public.key | sudo gpg --dearmor -o /usr/share/keyrings/dodate.gpg
```

### 2. Ajouter le repository

```bash
# Ajouter le repository à vos sources APT
echo 'deb [signed-by=/usr/share/keyrings/dodate.gpg] http://VOTRE-SERVEUR:PORT/apt/dodate stable main' | sudo tee /etc/apt/sources.list.d/dodate.list
```

### 3. Installer le package

```bash
# Mettre à jour et installer
sudo apt update
sudo apt install dodate
```

### Exemple complet

```bash
# Pour un serveur sur 192.168.1.100 port 8000
curl -fsSL http://192.168.1.100:8000/apt/public.key | sudo gpg --dearmor -o /usr/share/keyrings/dodate.gpg
echo 'deb [signed-by=/usr/share/keyrings/dodate.gpg] http://192.168.1.100:8000/apt/dodate stable main' | sudo tee /etc/apt/sources.list.d/dodate.list
sudo apt update
sudo apt install dodate
```

---

## 🔧 Déploiement manuel étape par étape

Si vous préférez contrôler chaque étape :

### 1. Construire le package

```bash
./scripts/build-dodate-deb.sh
```

### 2. Générer le repository

```bash
./scripts/deploy-apt-repositery.sh dodate_1.0.1_all.deb VOTRE_GPG_KEY_ID
```

### 3. Déployer manuellement

```bash
# Copier vers Apache
sudo cp -r dodate/* /var/www/html/apt/
sudo chown -R www-data:www-data /var/www/html/apt/
sudo chmod -R 755 /var/www/html/apt/

# Configurer Apache (voir configuration ci-dessous)
```

---

## ⚙️ Configuration Apache manuelle

Si vous voulez configurer Apache manuellement :

### 1. Créer le VirtualHost

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
    ErrorLog ${APACHE_LOG_DIR}/apt-repo-8000_error.log
    CustomLog ${APACHE_LOG_DIR}/apt-repo-8000_access.log combined
</VirtualHost>
```

### 2. Activer la configuration

```bash
# Ajouter le port
echo "Listen 8000" | sudo tee -a /etc/apache2/ports.conf

# Activer les modules
sudo a2enmod headers
sudo a2enmod dir

# Activer le site
sudo a2ensite apt-repo-8000.conf

# Redémarrer Apache
sudo systemctl restart apache2
```

---

## 🔍 Vérification et tests

### 1. Vérifier Apache

```bash
# Statut d'Apache
sudo systemctl status apache2

# Vérifier les ports en écoute
sudo netstat -tlnp | grep apache2
```

### 2. Tester le repository

```bash
# Tester l'accès HTTP
curl -I http://localhost:8000/apt/

# Tester la clé publique
curl -I http://localhost:8000/apt/public.key

# Tester les packages
curl -I http://localhost:8000/apt/dodate/stable/main/binary-all/Packages.gz
```

### 3. Tester l'installation

```bash
# Sur une machine cliente
curl -fsSL http://VOTRE-IP:8000/apt/public.key | sudo gpg --dearmor -o /usr/share/keyrings/dodate.gpg
echo 'deb [signed-by=/usr/share/keyrings/dodate.gpg] http://VOTRE-IP:8000/apt/dodate stable main' | sudo tee /etc/apt/sources.list.d/dodate.list
sudo apt update
apt list dodate
sudo apt install dodate
dodate
```

---

## 🚨 Dépannage

### Problèmes courants

#### 1. Erreur de permissions sur le fichier .deb

```bash
# Si vous avez l'erreur "_apt couldn't be accessed by user"
sudo chmod 644 package.deb
sudo chown root:root package.deb

# Ou installer depuis le repository au lieu du fichier local
sudo apt remove --purge dodate
sudo apt update
sudo apt install dodate
```

#### 2. Erreur de permissions du repository

```bash
sudo chown -R www-data:www-data /var/www/html/apt/
sudo chmod -R 755 /var/www/html/apt/
```

#### 2. Apache ne démarre pas

```bash
# Vérifier la configuration
sudo apache2ctl configtest

# Voir les logs d'erreur
sudo tail -f /var/log/apache2/error.log
```

#### 3. Clé GPG non reconnue

```bash
# Vérifier que la clé existe
gpg --list-secret-keys

# Régénérer la clé publique
gpg --export -a VOTRE_GPG_KEY_ID > /var/www/html/apt/public.key
```

#### 4. Port déjà utilisé

```bash
# Vérifier quel processus utilise le port
sudo netstat -tlnp | grep :8000

# Utiliser un autre port
sudo ./scripts/apache2-auto-deploy.sh VOTRE_GPG_KEY_ID "" 9000
```

---

## 🔄 Mise à jour du repository

Pour ajouter une nouvelle version de votre package :

```bash
# Construire la nouvelle version
./scripts/build-dodate-deb.sh

# Redéployer automatiquement
sudo ./scripts/apache2-auto-deploy.sh VOTRE_GPG_KEY_ID dodate_1.0.2_all.deb

# Ou manuellement
./scripts/deploy-apt-repositery.sh dodate_1.0.2_all.deb VOTRE_GPG_KEY_ID
sudo cp -r dodate/* /var/www/html/apt/
```

---

## 📝 Structure finale du repository

```
/var/www/html/apt/
├── dodate/
│   ├── dists/
│   │   └── stable/
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

## 🎯 Commandes de référence rapide

```bash
# Déploiement complet automatique
sudo ./scripts/apache2-auto-deploy.sh GPG_KEY_ID

# Avec port personnalisé
sudo ./scripts/apache2-auto-deploy.sh GPG_KEY_ID "" 9000

# Construction seule
./scripts/build-dodate-deb.sh

# Repository seul
./scripts/deploy-apt-repositery.sh package.deb GPG_KEY_ID

# Test client
curl -fsSL http://IP:PORT/apt/public.key | sudo gpg --dearmor -o /usr/share/keyrings/dodate.gpg
echo 'deb [signed-by=/usr/share/keyrings/dodate.gpg] http://IP:PORT/apt/dodate stable main' | sudo tee /etc/apt/sources.list.d/dodate.list
sudo apt update && sudo apt install dodate
```

---

**🎉 Votre repository APT Dodate est maintenant prêt et accessible !**

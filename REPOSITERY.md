# 📦 REPOSITORY.md

**Documentation du dépôt APT pour l’application `dodate`**

Cette documentation explique la mise en place, la structure, la sécurisation et l’utilisation d’un **dépôt APT personnalisé** pour l’application `dodate`. Elle suit les recommandations officielles de [Debian sur la structure des dépôts APT](https://wiki.debian.org/DebianRepository/Format).

---

## 📁 Structure du dépôt

Le dépôt respecte l’arborescence recommandée par Debian :

```
/var/www/html/apt/
├── dists/
│   └── dodate/
│       ├── main/
│       │   └── binary-all/
│       │       ├── Packages
│       │       └── Packages.gz
│       ├── Release
│       ├── Release.gpg
│       └── InRelease
├── pool/
│   └── dodate/
│       └── dodate_1.0.1_all.deb
└── public.key
```

### ✅ Justifications

- **`dists/`** : Contient les fichiers d’index et de métadonnées utilisés par APT (`Release`, `InRelease`, `Release.gpg`, etc.).
- **`pool/`** : Emplacement des fichiers `.deb`. Permet une gestion centralisée et non redondante des paquets.
- **`public.key`** : Clé publique GPG exportée en ASCII-armored, permettant aux clients APT de vérifier l’authenticité du dépôt.

---

## 🛠️ Génération des fichiers d’index

La génération des métadonnées du dépôt est réalisée avec les outils standards Debian :

```bash
# Depuis binary-all/
dpkg-scanpackages -m . > Packages
gzip -k -f Packages

# Depuis dists/dodate/
apt-ftparchive release . > Release
```

### ✅ Justification

- `dpkg-scanpackages` crée le fichier `Packages`, utilisé pour lister les paquets disponibles.
- `apt-ftparchive` permet de générer un fichier `Release` avec les checksums nécessaires (`MD5Sum`, `SHA256`, etc.).
- `gzip` permet de proposer une version compressée de `Packages`, comme attendu par les clients APT.

---

## 🔐 Signature cryptographique

Le fichier `Release` est signé avec GPG pour permettre la vérification par les clients :

```bash
gpg --default-key "<ID_CLÉ>" -abs -o Release.gpg Release
gpg --default-key "<ID_CLÉ>" --clearsign -o InRelease Release
```

### ✅ Justification

- `Release.gpg` : signature détachée.
- `InRelease` : signature intégrée.
- Ces signatures assurent l’intégrité et l’authenticité du dépôt, comme recommandé par Debian.

---

## 🌍 Hébergement via Apache2

Le dépôt est servi via HTTP grâce à un serveur Apache configuré sur un port dédié (ex. : `9000`). Le VirtualHost associé permet de séparer les services et d'ajuster la configuration :

```apache
<VirtualHost *:9000>
    ServerName apt.dopolytech.fr
    DocumentRoot /var/www/html/apt
    <Directory /var/www/html/apt>
        Options Indexes FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>
</VirtualHost>
```

### ✅ Justification

- L’exposition du dépôt via HTTP est la méthode la plus courante.
- L’utilisation d’un VirtualHost dédié assure la modularité du serveur web et permet une configuration fine.

---

## 🔑 Clé GPG publique

La clé utilisée pour signer les métadonnées est exportée en format ASCII et rendue accessible :

```bash
gpg --export -a "Nom de la clé" > /var/www/html/apt/public.key
```

URL d'accès (réseau Polytech) : `http://cygnus.dopolytech.fr:9000/public.key`

---

## 🧩 Utilisation sur une machine cliente Debian/Ubuntu

### 1. Import de la clé GPG :

```bash
sudo mkdir -p /etc/apt/keyrings
curl -fsSL http://cygnus.dopolytech.fr:9000/public.key | gpg --dearmor | sudo tee /etc/apt/keyrings/dodate.gpg > /dev/null
```

### 2. Ajout du dépôt APT :

```bash
echo "deb [signed-by=/etc/apt/keyrings/dodate.gpg] http://cygnus.dopolytech.fr:9000/ dodate main" | sudo tee /etc/apt/sources.list.d/dodate.list
```

### 3. Mise à jour de la liste des paquets :

```bash
sudo apt update
```

### ✅ Justification

- Le placement de la clé dans `/etc/apt/keyrings/` et l’utilisation de l’option `signed-by` assurent que seule cette clé sera utilisée pour ce dépôt, renforçant la sécurité.
- L’option `sources.list.d/` permet une gestion propre et modulaire des sources.

---

## 🔄 Automatisation du dépôt

Des scripts automatisent les étapes suivantes :

- **build-dodate-deb.sh** : génère le paquet `.deb` de l’application.
- **deploy-apt-repositery.sh** : met à jour les fichiers `Packages`, `Release`, `InRelease` et `Release.gpg`.
- **apache2-auto-deploy.sh** : déploie le dépôt sur le serveur Apache.

### ✅ Justification

Automatiser ces étapes garantit :

- Une régularité dans le format et le contenu du dépôt.
- Moins d’erreurs humaines.
- Un déploiement rapide en cas de mise à jour de version.

---

## ✅ Conformité Debian

Ce dépôt :

- Suit l’arborescence Debian (`dists/`, `pool/`, clés GPG).
- Utilise les outils Debian (`dpkg-scanpackages`, `apt-ftparchive`, `gpg`).
- Met en œuvre des mécanismes de sécurité adaptés (`signed-by`, signature GPG).
- Fournit une documentation claire pour les utilisateurs clients.

Il est donc **entièrement conforme** aux standards Debian.

---

## 📚 Ressources utiles

- [DebianRepository/Format — Debian Wiki](https://wiki.debian.org/DebianRepository/Format)
- [SecureApt — Debian Wiki](https://wiki.debian.org/SecureApt)
- [apt-ftparchive(1) — Debian Manpages](https://manpages.debian.org/apt-ftparchive)

---

Si vous avez des questions ou souhaitez contribuer à l’amélioration du dépôt, n’hésitez pas à ouvrir une **issue** ou une **pull request**.

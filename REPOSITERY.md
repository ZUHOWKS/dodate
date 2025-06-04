# 📦 Mise en place d’un dépôt APT personnalisé pour Dodate

Ce document décrit la méthode suivie pour concevoir, signer, héberger et rendre disponible un **dépôt APT** selon les bonnes pratiques Debian. Ce dépôt permet aux utilisateurs d’installer facilement l’application `dodate` via `apt`.

---

## 🧱 1. Structure du dépôt

Conformément à la [Debian Repository Layout](https://wiki.debian.org/DebianRepository/Format), le dépôt suit cette arborescence classique :

```
dodate/
├── dists/
│   └── stable/
│       └── main/
│           └── binary-all/
│               ├── Packages
│               └── Packages.gz
├── pool/
│   └── dodate/
│       └── dodate_1.0.0_all.deb
└── public.key
```

- `dists/` : contient les métadonnées APT (`Packages`, `Release`, signatures...).
- `pool/` : contient les fichiers `.deb`, classés par nom de package.
- `public.key` : clé publique GPG utilisée pour la vérification côté client.

---

## ⚙️ 2. Génération des index de paquets

Depuis le dossier `binary-all/`, nous avons généré les fichiers d’index nécessaires au fonctionnement d’APT :

```bash
dpkg-scanpackages -m . > Packages
gzip -k -f Packages  # Génère Packages.gz
```

Le fichier `Packages` référence les `.deb` disponibles et leur checksum.

---

## 📋 3. Création du fichier `Release`

Le fichier `Release` permet à APT de connaître la structure et les checksums du dépôt :

```bash
apt-ftparchive release . > Release
```

---

## 🔐 4. Signature cryptographique

Pour assurer l’intégrité et l’authenticité du dépôt, le fichier `Release` est signé avec une **clé GPG dédiée** :

```bash
gpg --default-key "<KEY_ID>" -abs -o Release.gpg Release
gpg --default-key "<KEY_ID>" --clearsign -o InRelease Release
```

- `Release.gpg` est utilisé par APT pour la vérification.
- `InRelease` combine `Release` et sa signature en un seul fichier lisible.

> 🔐 Bonnes pratiques :
>
> - Clé GPG dédiée au projet.
> - Clé exportée en ASCII (`.asc`) ou binaire (`.gpg`) pour les clients.
> - Signature **obligatoire** pour un usage sécurisé.

---

## 🌐 5. Publication HTTP

Le dépôt est hébergé sur un serveur HTTP, accessible via :

```
http://cygnus.dopolytech.fr/dodate/
```

Ce répertoire web expose :

- `dists/stable/...` : structure du dépôt
- `pool/dodate/` : fichiers `.deb`
- `public.key` : clé publique pour authentifier le dépôt

---

## 🗝 6. Publication de la clé publique GPG

Export de la clé publique au format ASCII :

```bash
gpg --export -a "Dodate Signing Key" > /var/www/html/dodate/public.key
```

Cette clé peut être importée sur les clients pour vérifier la signature du dépôt.

---

## 📥 7. Ajout côté client

### a. Import sécurisé de la clé GPG

```bash
sudo mkdir -p /etc/apt/keyrings
curl -fsSL http://cygnus.dopolytech.fr/dodate/public.key | gpg --dearmor | sudo tee /etc/apt/keyrings/dodate.gpg > /dev/null
```

### b. Ajout de la source APT

```bash
echo "deb [signed-by=/etc/apt/keyrings/dodate.gpg] http://cygnus.dopolytech.fr/dodate stable main" | sudo tee /etc/apt/sources.list.d/dodate.list
```

### c. Mise à jour et installation

```bash
sudo apt update
sudo apt install dodate
```

---

## 🔄 8. Script de mise à jour automatique

Un script peut être utilisé pour automatiser la régénération des métadonnées et la signature :

```bash
#!/bin/bash

set -e

REPO_DIR="/var/www/html/dodate"
DIST_DIR="$REPO_DIR/dists/stable/main/binary-all"
cd "$DIST_DIR"

dpkg-scanpackages -m . > Packages
gzip -k -f Packages

cd "$REPO_DIR/dists/stable"
apt-ftparchive release . > Release

gpg --default-key "<KEY_ID>" -abs -o Release.gpg Release
gpg --default-key "<KEY_ID>" --clearsign -o InRelease Release
```

---

## ✅ Bonnes pratiques respectées

| Élément                               | État | Détail                                      |
| ------------------------------------- | ---- | ------------------------------------------- |
| Structure Debian standard             | ✅   | `dists/`, `pool/`, `binary-all/`            |
| Clé GPG spécifique au projet          | ✅   | Sécurité et traçabilité                     |
| Signature `Release.gpg` / `InRelease` | ✅   | Compatible avec les clients modernes        |
| Public key téléchargeable             | ✅   | Clé accessible publiquement                 |
| Séparation claire `stable` / `main`   | ✅   | Bonne pratique pour la gestion des versions |
| Ajout sécurisé via `signed-by`        | ✅   | Conforme aux normes modernes APT            |

---

## 🔮 Évolutions possibles

- Support multi-architecture (`binary-amd64`, `binary-arm64`, etc.).
- Ajout d’un système CI pour publier automatiquement les `.deb`.
- Utilisation de `reprepro`, `aptly` ou `deb-s3` pour industrialiser.
- Mise en place de HTTPS (via Nginx + Let's Encrypt).

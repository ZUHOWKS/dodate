# 📦 Documentation Dodate APT Repositery

**Documentation for the APT repository for the `dodate` application**

This documentation explains the setup, structure, security, and usage of a **custom APT repository** for the `dodate` application. It follows the official [Debian recommendations on APT repository structure](https://wiki.debian.org/DebianRepository/Format).

---

## 📁 Repository Structure

The repository follows the recommended Debian hierarchy:

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

- **`dists/`**: Contains the index and metadata files used by APT (`Release`, `InRelease`, `Release.gpg`, etc.).
- **`pool/`**: Location for `.deb` files. Allows centralized and non-redundant package management.
- **`public.key`**: GPG public key exported in ASCII-armored format, allowing APT clients to verify the repository's authenticity.

---

## 🛠️ Index File Generation

The repository metadata is generated using standard Debian tools:

```bash
# From binary-all/
dpkg-scanpackages -m . > Packages
gzip -k -f Packages

# From dists/dodate/
apt-ftparchive release . > Release
```

### ✅ Justification

- `dpkg-scanpackages` creates the `Packages` file, used to list available packages.
- `apt-ftparchive` generates a `Release` file with the necessary checksums (`MD5Sum`, `SHA256`, etc.).
- `gzip` provides a compressed version of `Packages`, as expected by APT clients.

---

## 🔐 Cryptographic Signature

The `Release` file is signed with GPG to allow client verification:

```bash
gpg --default-key "<KEY_ID>" -abs -o Release.gpg Release
gpg --default-key "<KEY_ID>" --clearsign -o InRelease Release
```

### ✅ Justification

- `Release.gpg`: detached signature.
- `InRelease`: inline signature.
- These signatures ensure the integrity and authenticity of the repository, as recommended by Debian.

---

## 🌍 Hosting via Apache2

The repository is served over HTTP using an Apache server configured on a dedicated port (e.g., `9000`). The associated VirtualHost allows for service separation and fine-tuned configuration:

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

- Exposing the repository via HTTP is the most common method.
- Using a dedicated VirtualHost ensures modularity of the web server and allows for fine configuration.

---

## 🔑 Public GPG Key

The key used to sign the metadata is exported in ASCII format and made accessible:

```bash
gpg --export -a "Key Name" > /var/www/html/apt/public.key
```

Access URL (Polytech network): `http://cygnus.dopolytech.fr:9000/public.key`

---

## 🧩 Usage on a Debian/Ubuntu Client Machine

### 1. Import the GPG key:

```bash
sudo mkdir -p /etc/apt/keyrings
curl -fsSL http://cygnus.dopolytech.fr:9000/public.key | gpg --dearmor | sudo tee /etc/apt/keyrings/dodate.gpg > /dev/null
```

### 2. Add the APT repository:

```bash
echo "deb [signed-by=/etc/apt/keyrings/dodate.gpg] http://cygnus.dopolytech.fr:9000/ dodate main" | sudo tee /etc/apt/sources.list.d/dodate.list
```

### 3. Update the package list:

```bash
sudo apt update
```

### ✅ Justification

- Placing the key in `/etc/apt/keyrings/` and using the `signed-by` option ensures that only this key will be used for this repository, enhancing security.
- The use of `sources.list.d/` allows for clean and modular source management.

---

## 🔄 Repository Automation

Scripts automate the following steps:

- **build-dodate-deb.sh**: generates the application's `.deb` package.
- **deploy-apt-repositery.sh**: updates the `Packages`, `Release`, `InRelease`, and `Release.gpg` files.
- **apache2-auto-deploy.sh**: deploys the repository on the Apache server.

### ✅ Justification

Automating these steps ensures:

- Consistency in the repository's format and content.
- Fewer human errors.
- Fast deployment in case of version updates.

---

## ✅ Debian Compliance

This repository:

- Follows the Debian hierarchy (`dists/`, `pool/`, GPG keys).
- Uses Debian tools (`dpkg-scanpackages`, `apt-ftparchive`, `gpg`).
- Implements appropriate security mechanisms (`signed-by`, GPG signature).
- Provides clear documentation for client users.

It is therefore **fully compliant** with Debian standards.

---

## 📚 Useful Resources

- [DebianRepository/Format — Debian Wiki](https://wiki.debian.org/DebianRepository/Format)
- [SecureApt — Debian Wiki](https://wiki.debian.org/SecureApt)
- [apt-ftparchive(1) — Debian Manpages](https://manpages.debian.org/apt-ftparchive)

---

If you have any questions or wish to contribute to improving the repository, feel free to open an **issue** or a **pull request**.

# Official Repository Server Setup

This document summarizes all operations performed on the server to host and maintain the official `dodate` APT repository.

---

## 1. Prerequisites

- Ubuntu/Debian server with root or sudo access
- Installed packages:
  ```bash
  sudo apt update
  sudo apt install -y apache2 dpkg-dev apt-utils gnupg2
  ```
- Ensure firewall allows chosen port (default **9000**):
  ```bash
  sudo ufw allow 9000/tcp
  ```

---

## 2. Repository Directory Structure

All files are served under the Apache document root:

```
/var/www/html/apt/
├── dists/dodate/main/binary-all/  # Metadata and Packages files
├── pool/main/dodate/              # .deb package files
└── public.key                     # GPG public key
```

- **dists/**: Contains `Release`, `InRelease`, `Release.gpg`, and `Packages` files
- **pool/**: Holds `.deb` files organized by component and package name
- **public.key**: Exported GPG key used by clients

---

## 3. Deployed Scripts

Scripts are stored in the project under `/home/joris/dev/projects/dodate/scripts` and deployed to:

- `/usr/local/bin/build-dodate-deb.sh` (build package)
- `/usr/local/bin/deploy-apt-repositery.sh` (generate metadata)
- `/usr/local/bin/apache2-auto-deploy.sh` (orchestrate build & deploy)
- `/usr/local/bin/auto-update-apt-repositery.sh` (cron auto-update)
- `/usr/local/bin/uninstall-apt-repository.sh` (clean removal)

Make all scripts executable:

```bash
sudo chmod +x /usr/local/bin/*.sh
```

---

## 4. Apache Configuration

1. Create a VirtualHost file `/etc/apache2/sites-available/apt-repo-9000.conf`:

   ```apache
   <VirtualHost *:9000>
     DocumentRoot /var/www/html/apt
     ServerName localhost

     <Directory /var/www/html/apt>
       Options Indexes FollowSymLinks
       Require all granted
     </Directory>

     ErrorLog ${APACHE_LOG_DIR}/apt-repo_error.log
     CustomLog ${APACHE_LOG_DIR}/apt-repo_access.log combined
   </VirtualHost>
   ```

2. Add port to `/etc/apache2/ports.conf`:
   ```bash
   echo 'Listen 9000' | sudo tee -a /etc/apache2/ports.conf
   ```
3. Enable site and modules:
   ```bash
   sudo a2enmod headers dir
   sudo a2ensite apt-repo-9000.conf
   sudo systemctl reload apache2
   ```

---

## 5. GPG Key to Sign Repository

To ensure the authenticity and integrity of the repository metadata, the `Release` file must be signed:

- As root, generate or use an existing GPG key:

  ```bash
  sudo -i        # switch to root
  gpg --full-generate-key
  ```

- Export the public key for client distribution:

  ```bash
  gpg --armor --export <KEY_ID> > /var/www/html/apt/public.key
  ```

- The private key remains in root's keyring at `/root/.gnupg/` and is used by the deployment scripts to sign files.

- Verify that the public key is accessible:

  ```bash
  curl -I http://<SERVER_IP>:9000/apt/public.key
  ```

- Sign the `Release` file (executed automatically by `deploy-apt-repositery.sh`):
  ```bash
  gpg --default-key "$GPG_KEY_ID" --detach-sign -o "$REL_DIST_DIR/Release.gpg" "$REL_DIST_DIR/Release"
  gpg --default-key "$GPG_KEY_ID" --clearsign -o "$REL_DIST_DIR/InRelease" "$REL_DIST_DIR/Release"
  ```

---

## 6. Automatic Updates (Cron) (NOT ENABLED)

Can schedule `auto-update-apt-repositery.sh`:

```cron
*/5 * * * * root /usr/local/bin/auto-update-apt-repositery.sh >/var/log/apt-repo-update.log 2>&1
```

This regenerates `Packages` and `Release` when new `.deb` packages appear.

---

## 7. Permissions & Ownership

Ensure Apache can read all files:

```bash
sudo chown -R www-data:www-data /var/www/html/apt
sudo chmod -R 755 /var/www/html/apt
```

---

## 8. Backup Strategy

Prior to each deployment, the old repository can be backed up:

```bash
mv /var/www/html/apt /var/www/html/apt.backup.$(date +"%Y%m%d_%H%M%S")
```

Automated by `apache2-auto-deploy.sh`.

---

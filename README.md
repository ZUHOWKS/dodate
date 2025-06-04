# 📦 `dodate` Debian Package

This repository provides the necessary structure and tooling to package the `dodate` Python program into a `.deb` file, making it easily installable on Debian-based systems.

`dodate` is a small utility that displays the current local time as well as the time in Réunion Island 🇷🇪.

## 📚 Documentation

- 📋 **[Repository Structure](./REPOSITERY.md)** - Detailed explanation of APT repository design and best practices
- 🚀 **[Deployment Guide](./DEPLOY-REPOSITERY.md)** - Complete guide for deploying the APT repository with automated scripts
- 📦 **[Package Build Process](#-build-steps)** - Build instructions for the Debian package (this document)

---

## ⚙️ Project Structure

- `dodate/` – Python source code
- `debian/` – Debian packaging files (e.g., `control`, `postinst`, file structure)
- `mirror/` – Example trivial mirror and GPG signing setup

---

## 🛠️ Manual Build Steps

### 1. Build the `.deb` Package

Make sure your Python script is ready and your Debian control files are in place.

```bash
dpkg-deb --build dodate/
```

This will generate a `dodate.deb` file in the current directory.

### 2. Create a Trivial APT Mirror

To simulate a local APT repository:

```bash
mkdir -p repo/binary
cp dodate.deb repo/binary/
dpkg-scanpackages repo/binary /dev/null | gzip -9c > repo/binary/Packages.gz
```

To use this local mirror, add it to your APT sources list:

```bash
echo "deb [trusted=yes] file://$(pwd)/repo binary/" | sudo tee /etc/apt/sources.list.d/dodate-local.list
```

You can now install the package using:

```bash
sudo apt-get update
sudo apt-get install dodate
```

_(after configuring `sources.list` to point to your local mirror)_

### 3. Trusted Mirror with GPG

To sign your repository with GPG:

- Generate a GPG key (if not already done):

  ```bash
  gpg --gen-key
  ```

- Export the public key:

  ```bash
  gpg --export --armor KEY_ID > repo/public.key
  ```

- Sign the `Release` file:

  ```bash
  apt-ftparchive release repo/binary > repo/binary/Release
  gpg --default-key KEY_ID -abs -o repo/binary/Release.gpg repo/binary/Release
  ```

- Ensure your system trusts the GPG key before installing.

---

## 📁 Filesystem Layout

The `dodate` binary will be installed in `/usr/lib/dodate`:

```
/usr/lib/dodate/dodate.py
```

A symbolic link will be created during installation to allow global access:

```
/usr/bin/dodate → /usr/lib/dodate/dodate.py
```

This ensures `dodate` is executable system-wide:

```bash
dodate
```

---

## 📄 Debian Package Details

The `debian/control` file specifies:

- Dependencies (e.g., Python version)
- Conflicts (if any)
- Maintainer and versioning metadata

**Post-install hooks** can be added via:

- `postinst` for symlink creation
- `prerm` or `postrm` for cleanup

---

## 🔒 Constraints

- The executable must reside under `/usr/lib/dodate`
- A symlink must be present in `/usr/bin`
- Python dependencies should be minimal or vendored

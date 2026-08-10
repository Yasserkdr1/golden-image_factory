<div align="center">

# 📦 VirtualBox Golden Image

### Ubuntu 24.04 · Packer · Ansible · VirtualBox

![VirtualBox](https://img.shields.io/badge/VirtualBox-Image_Build-183A61?style=for-the-badge&logo=virtualbox&logoColor=white)
![Packer](https://img.shields.io/badge/Packer-HashiCorp-02A8EF?style=for-the-badge&logo=packer&logoColor=white)
![Ansible](https://img.shields.io/badge/Ansible-Hardening-EE0000?style=for-the-badge&logo=ansible&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04_LTS-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)

</div>

---

## 📖 Overview

This directory contains the Packer configuration used to create the **Ubuntu 24.04 VirtualBox Golden Image**.

Two build methods are available:

```text
                    VirtualBox Golden Image
                             │
                 ┌───────────┴───────────┐
                 │                       │
                 ▼                       ▼
           Local Build              CI/CD Build
                 │                       │
         Developer Machine         GitHub Runner
                 │                       │
                 └───────────┬───────────┘
                             ▼
                           Packer
                             │
                             ▼
                         VirtualBox
                             │
                             ▼
                          Ansible
                             │
                             ▼
                    Security Hardening
                             │
                             ▼
                    Lynis + OpenSCAP
                             │
                             ▼
                     VirtualBox Image
```

---

#  Method 1 — Local Build

## Prerequisites

The local workstation must provide:

```text
Git
Packer
VirtualBox
Ansible
```

Check:

```bash
git --version
packer version
VBoxManage --version
ansible --version
ansible-playbook --version
```

---

## Clone the Repository

```bash
git clone https://github.com/Yasserkdr1/golden-image_factory.git
cd golden-image_factory
```

Install the required Ansible collections:

```bash
ansible-galaxy collection install \
  -r ansible/requirements.yml
```

---

# ⚙️ Local Packer Variables

A template configuration file is provided for local development.

Do **not** directly edit the `.example` file.

Move to the VirtualBox directory:

```bash
cd packer/virtualbox
```

Copy the example:

```bash
cp ubuntu.auto.pkrvars.hcl.example ubuntu.auto.pkrvars.hcl
```

You should now have:

```text
ubuntu.auto.pkrvars.hcl.example   ← template committed to Git
ubuntu.auto.pkrvars.hcl           ← local configuration
```

Edit the local file:

```bash
nano ubuntu.auto.pkrvars.hcl
```

Configure the variables required by the VirtualBox Packer template, including the Ubuntu ISO location and checksum.

For example:

```hcl
iso_url      = "file:///absolute/path/to/ubuntu-24.04.4-live-server-amd64.iso"
iso_checksum = "sha256:YOUR_SHA256_CHECKSUM"
```

Use the exact variable names defined by the Packer configuration in this directory.

The local `.pkrvars.hcl` file should remain excluded from Git when it contains workstation-specific values.

---

# 🔐 Local Secrets

Sensitive values are stored separately in a local:

```text
.env
```

Create it from the repository root:

```bash
nano .env
```

Example:

```bash
GRUB_PASSWORD_HASH="grub.pbkdf2.sha512.10000.YOUR_HASH_HERE"
```

The real hash must never be committed.

Make sure `.env` is ignored:

```bash
git check-ignore .env
```

---

## Load `.env`

From the repository root:

```bash
set -a
source .env
set +a
```

Then expose the GRUB hash to Packer:

```bash
export PKR_VAR_grub_password_hash="$GRUB_PASSWORD_HASH"
```

Verify that the variable is loaded **without printing its value**:

```bash
printf '%s\n' "${#PKR_VAR_grub_password_hash}"
```

Expected result:

```text
a non-zero number
```

This checks only the length of the secret.

---

# 🧪 Validate the Local Build

Move into:

```bash
cd packer/virtualbox
```

Initialize Packer:

```bash
packer init .
```

Format:

```bash
packer fmt -recursive .
```

Check formatting:

```bash
packer fmt -check -recursive .
```

Validate:

```bash
packer validate .
```

---

# 🚀 Build Locally

Run:

```bash
packer build .
```

The build follows:

```text
Ubuntu ISO
    │
    ▼
VirtualBox VM
    │
    ▼
Ubuntu Autoinstall
    │
    ▼
SSH
    │
    ▼
Ansible Hardening
    │
    ▼
Reboot
    │
    ▼
Ansible Verification
    │
    ▼
Lynis + OpenSCAP
    │
    ▼
Image Cleanup
    │
    ▼
VirtualBox Golden Image
```

---

# Method 2 — GitHub Actions / Runner

The VirtualBox image can also be built automatically through GitHub Actions using a compatible runner.

The runner must be capable of running VirtualBox.

---

## 🔐 Repository Secrets

Go to:

```text
Repository
→ Settings
→ Secrets and variables
→ Actions
→ Secrets
```

Create the following secrets:

| Secret | Purpose |
|---|---|
| `GRUB_PASSWORD_HASH` | GRUB PBKDF2 password hash |
| `PACKER_SSH_PASSWORD` | SSH password used during the Packer build |
| `PACKER_SSH_PRIVATE_KEY` | Private SSH key used by the automated build |

These values must **never** be committed to the repository.

Example workflow mapping:

```yaml
env:
  PKR_VAR_grub_password_hash: ${{ secrets.GRUB_PASSWORD_HASH }}
  PKR_VAR_ssh_password: ${{ secrets.PACKER_SSH_PASSWORD }}
```

The private SSH key should be handled only by the workflow step that requires it and should never be printed to the job logs.

---

# ⚙️ Repository Variables

Non-sensitive build configuration is stored under:

```text
Repository
→ Settings
→ Secrets and variables
→ Actions
→ Variables
```

The VirtualBox build uses repository variables for values such as the Ubuntu installation media.

Current repository variables include:

```text
UBUNTU_ISO_URI
UBUNTU_ISO_CHECKSUM
```

Their purpose is:

| Variable | Purpose |
|---|---|
| `UBUNTU_ISO_URI` | Location of the Ubuntu 24.04 Server ISO accessible to the runner |
| `UBUNTU_ISO_CHECKSUM` | SHA-256 checksum used by Packer to verify the ISO |

These are **variables**, not secrets.

---

## ⚠️ ISO Path and Runner Location

A local URI such as:

```text
file:///home/user/os/ubuntu-24.04.4-live-server-amd64.iso
```

only works when the runner has that exact file available.

Therefore:

```text
Local workstation
       │
       └── local ISO path ✅
```

and:

```text
Self-hosted runner
       │
       └── ISO must exist on that runner ✅
```

A GitHub-hosted runner cannot access a file stored only on a developer workstation.

---

# Runner Requirements

The machine running the VirtualBox pipeline must provide:

```text
Packer
VirtualBox
Ansible
hardware virtualization
sufficient disk space
required privileges
Ubuntu installation media
```

This usually means using a:

```text
self-hosted GitHub Actions runner
```

for VirtualBox builds.

---

# 🔄 Local vs CI/CD

| Configuration | Local Build | GitHub Actions |
|---|---|---|
| Ubuntu ISO URI | `.pkrvars.hcl` | Repository Variable |
| Ubuntu checksum | `.pkrvars.hcl` | Repository Variable |
| GRUB hash | `.env` | Repository Secret |
| SSH password | local configuration | Repository Secret |
| SSH private key | local configuration | Repository Secret |
| Packer | Local | Runner |
| VirtualBox | Local | Runner |
| Ansible | Local | Runner |
| Compliance | ✅ | ✅ |
| Automated artifact handling | Optional | ✅ |

---

# 🔐 Secret Flow

### Local

```text
.env
 │
 └── GRUB_PASSWORD_HASH
          │
          ▼
export PKR_VAR_grub_password_hash
          │
          ▼
        Packer
```

### GitHub Actions

```text
GitHub Secrets
      │
      ├── GRUB_PASSWORD_HASH
      ├── PACKER_SSH_PASSWORD
      └── PACKER_SSH_PRIVATE_KEY
                    │
                    ▼
             GitHub Runner
                    │
                    ▼
                  Packer
```

---

# 🛡️ Security Rules

Never commit:

```text
.env
GRUB password hashes
SSH passwords
private SSH keys
temporary credentials
runner credentials
```

Before committing, check:

```bash
git status
```

and optionally:

```bash
git check-ignore .env
```

The repository also contains:

```text
.gitleaks.toml
```

to support secret scanning.

---

#  Troubleshooting

## GRUB variable is empty

Check:

```bash
printf '%s\n' "${#GRUB_PASSWORD_HASH}"
```

Then:

```bash
printf '%s\n' "${#PKR_VAR_grub_password_hash}"
```

If necessary:

```bash
export PKR_VAR_grub_password_hash="$GRUB_PASSWORD_HASH"
```

---

## `.pkrvars.hcl` does not exist

Create it from the example:

```bash
cp ubuntu.auto.pkrvars.hcl.example ubuntu.auto.pkrvars.hcl
```

Then edit:

```bash
nano ubuntu.auto.pkrvars.hcl
```

---

## Packer formatting fails

Run:

```bash
packer fmt -recursive .
```

Then:

```bash
packer fmt -check -recursive .
```

---

## ISO cannot be found

Verify the configured file:

```bash
ls -lh /path/to/ubuntu.iso
```

and check the configured URI.

---

## VirtualBox is unavailable

Check:

```bash
VBoxManage --version
```

---

# 📚 Related Documentation

➡️ [Main Project README](../../README.md)

➡️ [Google Cloud Golden Image](../gcp/README.md)

---

<div align="center">

### 📦 Local or automated. Same hardening. Same validation.

</div>
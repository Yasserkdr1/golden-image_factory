<div align="center">

# 🔐 Golden Image Factory

### Automated Ubuntu 24.04 Hardening, Compliance & Golden Image Pipeline

Build, harden, validate and deliver secure **Ubuntu 24.04 LTS Golden Images** across local virtualization and Google Cloud environments.

<br>

![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04_LTS-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
![Packer](https://img.shields.io/badge/Packer-HashiCorp-02A8EF?style=for-the-badge&logo=packer&logoColor=white)
![Ansible](https://img.shields.io/badge/Ansible-Automation-EE0000?style=for-the-badge&logo=ansible&logoColor=white)
![VirtualBox](https://img.shields.io/badge/VirtualBox-Local_Build-183A61?style=for-the-badge&logo=virtualbox&logoColor=white)
![Google Cloud](https://img.shields.io/badge/Google_Cloud-GCP-4285F4?style=for-the-badge&logo=googlecloud&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-CI%2FCD-2088FF?style=for-the-badge&logo=githubactions&logoColor=white)

<br>

![Lynis](https://img.shields.io/badge/Lynis-Security_Audit-2E8B57?style=flat-square)
![OpenSCAP](https://img.shields.io/badge/OpenSCAP-Compliance-4169E1?style=flat-square)
![CIS](https://img.shields.io/badge/CIS-Security_Benchmark-5A5A5A?style=flat-square)
![IaC](https://img.shields.io/badge/Infrastructure-as_Code-623CE4?style=flat-square)

</div>

---

## Overview

**Golden Image Factory** is a DevSecOps project that automates the creation of hardened Ubuntu 24.04 LTS machine images.

Instead of manually securing each new server, the project applies security controls during the image build process and produces reusable **Golden Images**.

The project combines:

- **Packer** for image creation
- **Ansible** for security hardening
- **Lynis** for Linux security auditing
- **OpenSCAP** for compliance validation
- **GitHub Actions** for CI/CD automation
- **VirtualBox** for local virtualization builds
- **Google Cloud Platform** for cloud Golden Images
- **Workload Identity Federation** for keyless GitHub → GCP authentication

---

## Goals

The project is designed to provide a repeatable security pipeline capable of:

- Building Ubuntu 24.04 images automatically
- Applying consistent security hardening
- Reusing the same Ansible roles across platforms
- Running post-hardening functional tests
- Auditing the final system with Lynis
- Evaluating compliance with OpenSCAP
- Rejecting non-compliant builds
- Creating reusable Golden Images
- Automating builds through GitHub Actions
- Avoiding long-lived GCP credentials

---

## Architecture

```text
                           GitHub Repository
                                  │
                                  ▼
                         ┌─────────────────┐
                         │ GitHub Actions  │
                         └────────┬────────┘
                                  │
                   ┌──────────────┴──────────────┐
                   │                             │
                   ▼                             ▼
          ┌─────────────────┐          ┌─────────────────┐
          │   VirtualBox    │          │      GCP        │
          │ Local / Runner  │          │ Compute Engine  │
          └────────┬────────┘          └────────┬────────┘
                   │                            │
                   └─────────────┬──────────────┘
                                 │
                                 ▼
                        ┌─────────────────┐
                        │     Packer      │
                        └────────┬────────┘
                                 │
                                 ▼
                        ┌─────────────────┐
                        │     Ansible     │
                        │    Hardening    │
                        └────────┬────────┘
                                 │
                                 ▼
                              Reboot
                                 │
                                 ▼
                        Ansible Verification
                                 │
                       ┌─────────┴─────────┐
                       ▼                   ▼
                    Lynis              OpenSCAP
                       │                   │
                       └─────────┬─────────┘
                                 ▼
                          Security Gates
                                 │
                                 ▼
                           Golden Image
```

---

## Technology Stack

| Technology | Purpose |
|---|---|
| Ubuntu 24.04 LTS | Base operating system |
| Packer | Machine image creation |
| Ansible | Configuration management and hardening |
| VirtualBox | Local virtualization |
| Google Compute Engine | Cloud image creation |
| GitHub Actions | CI/CD automation |
| Workload Identity Federation | Keyless GCP authentication |
| Lynis | Security auditing |
| OpenSCAP | Compliance evaluation |
| CIS Benchmark | Security hardening reference |
| Bash | Validation and cleanup scripts |
| Git | Version control |

---

##  Security Hardening

The Ansible roles cover several security domains:

```text
Authentication & PAM
Password policies
SSH hardening
Sudo configuration
Kernel hardening
Network sysctl
nftables firewall
auditd
journald / rsyslog
AppArmor
AIDE
Fail2ban
Filesystem permissions
Mount hardening
Kernel module restrictions
GRUB hardening
Time synchronization
Security banners
System cleanup
```

Platform-specific features can be enabled or disabled through Ansible and Packer variables.

---

##  Security Validation

Hardening is followed by automated validation.

### Lynis

Lynis performs a security audit of the resulting system.

The current build gate requires:

```text
Lynis hardening score >= 88
```

A score below the required threshold causes the build to fail.

### OpenSCAP

OpenSCAP evaluates Ubuntu against security compliance rules and generates:

```text
openscap-results.xml
openscap-report.html
```

### Ansible Verification

Post-hardening playbooks verify that security configuration has not broken essential system functionality.

---

## 📁 Repository Structure

```text
golden-image_factory/
│
├── .github/
│   └── workflows/
│       ├── gcp-golden-image.yml
│       └── ...
│
├── ansible/
│   ├── roles/
│   ├── tests/
│   │   ├── smoke.yml
│   │   ├── security.yml
│   │   ├── verify.yml
│   │   └── vars/
│   │       ├── cloud.yml
│   │       └── virtualbox.yml
│   ├── requirements.yml
│   └── site.yml
│
├── compliance/
│   ├── lynis/
│   └── openscap/
│
├── packer/
│   ├── virtualbox/
│   │   └── README.md
│   │
│   └── gcp/
│       └── README.md
│
├── scripts/
│   └── cleanup-image.sh
│
├── .gitignore
├── .gitleaks.toml
├── .yamllint.yml
└── README.md
```

---

# 🚀 Build Documentation

Golden Image Factory currently supports two image targets.

## 📦 VirtualBox

VirtualBox supports two build modes:

- **Local workstation build**
- **GitHub Actions / compatible runner build**

The VirtualBox documentation covers:

- local prerequisites
- Ubuntu ISO configuration
- `.env` configuration
- GRUB password handling
- Packer SSH credentials
- `.pkrvars.hcl.example` configuration
- local Packer builds
- GitHub Actions variables and secrets
- runner requirements

➡️ **[VirtualBox Golden Image Guide](packer/virtualbox/README.md)**

---

## ☁️ Google Cloud Platform

The GCP image is built using Packer and Google Compute Engine.

GitHub Actions authenticates to GCP using:

```text
GitHub OIDC
        +
Google Workload Identity Federation
```

No long-lived service account JSON key is required.

The GCP documentation covers:

- required Google APIs
- service account configuration
- IAM roles
- Workload Identity Pool
- GitHub OIDC Provider
- GitHub repository variables
- Packer configuration
- CI/CD execution
- image verification

➡️ **[Google Cloud Golden Image Guide](packer/gcp/README.md)**

---

## 🔄 Build Lifecycle

```text
Source Image
     │
     ▼
   Packer
     │
     ▼
Temporary VM
     │
     ▼
   Ansible
     │
     ▼
  Hardening
     │
     ▼
   Reboot
     │
     ▼
 Verification
     │
  ┌──┴──┐
  ▼     ▼
Lynis OpenSCAP
  │     │
  └──┬──┘
     ▼
Compliance Gate
     │
     ▼
Image Cleanup
     │
     ▼
Golden Image
```

---

## 🔐 Secrets Management

Sensitive credentials are never intended to be committed to Git.

Depending on the target platform, secrets are supplied through:

```text
Local build
    │
    └── .env

CI/CD build
    │
    └── GitHub Actions Secrets
```

Google Cloud builds use Workload Identity Federation instead of permanent service account keys.

The repository also includes secret scanning configuration through:

```text
.gitleaks.toml
```

---

## 🌐 Supported Targets

| Target | Local | CI/CD | Status |
|---|---:|---:|---:|
| VirtualBox | ✅ | ✅ | ✅ |
| Google Cloud | ✅ | ✅ | ✅ |

---

## 📚 Documentation

| Guide | Documentation |
|---|---|
|VirtualBox | [VirtualBox Build Guide](packer/virtualbox/README.md) |
|Google Cloud | [GCP Build Guide](packer/gcp/README.md) |
|Ansible | [`ansible/`](ansible/) |
|Compliance | [`compliance/`](compliance/) |
|CI/CD | [`.github/workflows/`](.github/workflows/) |

---

<div align="center">

### 🔐 Build once. Harden consistently. Validate automatically.

**Golden Image Factory**

</div>
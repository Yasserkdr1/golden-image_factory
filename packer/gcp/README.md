<div align="center">

# ☁️ Google Cloud Golden Image

### Ubuntu 24.04 · Packer · Ansible · GitHub Actions · Workload Identity Federation

![Google Cloud](https://img.shields.io/badge/Google_Cloud-GCP-4285F4?style=for-the-badge&logo=googlecloud&logoColor=white)
![Packer](https://img.shields.io/badge/Packer-HashiCorp-02A8EF?style=for-the-badge&logo=packer&logoColor=white)
![Ansible](https://img.shields.io/badge/Ansible-Hardening-EE0000?style=for-the-badge&logo=ansible&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-OIDC-2088FF?style=for-the-badge&logo=githubactions&logoColor=white)

</div>

---

## 📖 Overview

This directory contains the Packer configuration used to create the hardened Ubuntu 24.04 Golden Image on **Google Cloud Platform**.

The cloud pipeline combines:

```text
GitHub Actions
      │
      ▼
Workload Identity Federation
      │
      ▼
GCP Service Account
      │
      ▼
Packer
      │
      ▼
Compute Engine
      │
      ▼
Ansible Hardening
      │
      ▼
Lynis + OpenSCAP
      │
      ▼
GCP Golden Image
```

The authentication architecture does **not require a long-lived Google service account JSON key**.

---

# Authentication Architecture

```text
GitHub Repository
       │
       ▼
GitHub Actions
       │
       │ OIDC Token
       ▼
Google Workload Identity Pool
       │
       ▼
GitHub OIDC Provider
       │
       ▼
Packer Service Account
       │
       ▼
Google Compute Engine
```

---

# Prerequisites

Before running the GCP pipeline, the following components must exist:

- Google Cloud project
- Compute Engine enabled
- dedicated Packer service account
- Workload Identity Pool
- GitHub OIDC Provider
- GitHub → Service Account IAM binding
- required GCP APIs
- required IAM roles
- GitHub repository variables

---

# Required Google APIs

Set your project:

```bash
PROJECT_ID="YOUR_GCP_PROJECT_ID"
```

Enable:

```bash
gcloud services enable \
  compute.googleapis.com \
  iamcredentials.googleapis.com \
  cloudresourcemanager.googleapis.com \
  --project="$PROJECT_ID"
```

Verify:

```bash
gcloud services list \
  --project="$PROJECT_ID" \
  --enabled \
  --filter="config.name:(compute.googleapis.com OR iamcredentials.googleapis.com OR cloudresourcemanager.googleapis.com)" \
  --format="table(config.name)"
```

Expected APIs:

```text
cloudresourcemanager.googleapis.com
compute.googleapis.com
iamcredentials.googleapis.com
```

---

# 👤 Packer Service Account

Create a dedicated service account:

```bash
gcloud iam service-accounts create packer-github \
  --project="$PROJECT_ID" \
  --display-name="GitHub Packer Service Account"
```

The account follows:

```text
packer-github@PROJECT_ID.iam.gserviceaccount.com
```

Set:

```bash
SA="packer-github@${PROJECT_ID}.iam.gserviceaccount.com"
```

---

# 🔑 IAM Roles

The service account requires:

```text
roles/compute.instanceAdmin.v1
roles/iam.serviceAccountUser
```

Assign:

```bash
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SA}" \
  --role="roles/compute.instanceAdmin.v1"
```

```bash
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SA}" \
  --role="roles/iam.serviceAccountUser"
```

When IAP SSH tunneling is enabled, the following role may also be used:

```text
roles/iap.tunnelResourceAccessor
```

Verify:

```bash
gcloud projects get-iam-policy "$PROJECT_ID" \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:${SA}" \
  --format="table(bindings.role)"
```

---

#  Workload Identity Federation

GitHub Actions authenticates to Google Cloud using GitHub's OIDC identity.

This avoids:

```text
❌ Service Account JSON key
❌ Permanent GCP credential stored in GitHub
```

and instead uses:

```text
✅ Short-lived authentication
✅ GitHub OIDC
✅ Workload Identity Federation
```

---

# 🏊 Create the Workload Identity Pool

```bash
gcloud iam workload-identity-pools create github-pool \
  --project="$PROJECT_ID" \
  --location="global" \
  --display-name="GitHub Actions Pool"
```

Retrieve the project number:

```bash
PROJECT_NUMBER="$(
  gcloud projects describe "$PROJECT_ID" \
    --format="value(projectNumber)"
)"
```

Verify:

```bash
echo "$PROJECT_NUMBER"
```

---

# 🔌 Create the GitHub Provider

```bash
gcloud iam workload-identity-pools providers create-oidc github-provider \
  --project="$PROJECT_ID" \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --display-name="GitHub Provider" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository"
```

The provider should be restricted to the expected GitHub repository.

---

# 🔐 Allow GitHub to Use the Service Account

The GitHub identity must receive:

```text
roles/iam.workloadIdentityUser
```

on the Packer service account.

The binding should restrict impersonation to the intended repository.

The resulting chain becomes:

```text
GitHub repository
      │
      ▼
Workload Identity Provider
      │
      ▼
roles/iam.workloadIdentityUser
      │
      ▼
packer-github Service Account
```

---

#  Get the Provider Identifier

Run:

```bash
gcloud iam workload-identity-pools providers describe github-provider \
  --project="$PROJECT_ID" \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --format="value(name)"
```

Result format:

```text
projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider
```

This full value is stored in GitHub as:

```text
GCP_WORKLOAD_IDENTITY_PROVIDER
```

---

#  GitHub Repository Variables

Go to:

```text
Repository
→ Settings
→ Secrets and variables
→ Actions
→ Variables
```

Configure:

| Variable | Purpose |
|---|---|
| `GCP_PROJECT_ID` | Target GCP project |
| `GCP_ZONE` | Temporary Packer VM zone |
| `GCP_PACKER_SERVICE_ACCOUNT` | Service account used by GitHub Actions |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | Complete Workload Identity Provider identifier |

Example workflow references:

```yaml
${{ vars.GCP_PROJECT_ID }}
${{ vars.GCP_ZONE }}
${{ vars.GCP_PACKER_SERVICE_ACCOUNT }}
${{ vars.GCP_WORKLOAD_IDENTITY_PROVIDER }}
```

These are configuration identifiers rather than long-lived authentication secrets.

---

# 🔐 GitHub OIDC Permission

The workflow requires:

```yaml
permissions:
  contents: read
  id-token: write
```

`id-token: write` allows the job to obtain the GitHub OIDC token used for Workload Identity Federation.

---

# 🔑 Authentication Step

```yaml
- name: Authenticate to Google Cloud
  id: auth
  uses: google-github-actions/auth@v3
  with:
    workload_identity_provider: ${{ vars.GCP_WORKLOAD_IDENTITY_PROVIDER }}
    service_account: ${{ vars.GCP_PACKER_SERVICE_ACCOUNT }}
```

Then:

```yaml
- name: Setup Google Cloud CLI
  uses: google-github-actions/setup-gcloud@v3
```

---

#  Packer Environment Variables

The workflow maps GitHub configuration to Packer:

```yaml
env:
  PKR_VAR_project_id: ${{ vars.GCP_PROJECT_ID }}
  PKR_VAR_zone: ${{ vars.GCP_ZONE }}
```

Packer automatically maps:

```text
PKR_VAR_project_id
        │
        ▼
var.project_id
```

and:

```text
PKR_VAR_zone
        │
        ▼
var.zone
```

---

#  Packer Build Configuration

The GCP builder uses the official Ubuntu image family:

```hcl
source_image_family      = "ubuntu-2404-lts-amd64"
source_image_project_id  = ["ubuntu-os-cloud"]
```

Typical build resources:

```hcl
machine_type = "e2-medium"

disk_size = 20
disk_type = "pd-balanced"
```

The resulting image naming convention is:

```text
ubuntu-2404-golden-YYYYMMDD-HHMMSS
```

---

#  SSH Connectivity

The current build can use a temporary external IP:

```hcl
use_iap          = true
```
---

#  Ansible Hardening

Packer executes the common hardening playbook:

```text
ansible/site.yml
```

Cloud-specific variables disable configuration that is inappropriate for the cloud image.

Example:

```text
packages_full_upgrade_enabled=true
grub_hardening_enabled=false
grub_password_enabled=false
mount_hardening_separate_filesystems_enabled=false
time_sync_backend=chrony
```

This allows the same Ansible roles to support multiple platforms.

---

# 🔄 Reboot

After hardening:

```text
Ansible
   │
   ▼
Reboot
   │
   ▼
SSH reconnect
   │
   ▼
Verification
```

If the VM fails to reconnect, the Packer build fails.

---

# 🧪 Verification

Packer executes:

```text
ansible/tests/verify.yml
```

with:

```text
ansible/tests/vars/cloud.yml
```

and:

```text
image_platform=cloud
```

---

# 🛡️ OpenSCAP

The OpenSCAP datastream:

```text
compliance/openscap/ssg-ubuntu2404-ds.xml
```

is copied to the temporary VM.

The validation script is:

```text
compliance/openscap/check-compliance.sh
```

Reports include:

```text
openscap-results.xml
openscap-report.html
```

---

# 🔍 Lynis

Lynis validation is performed using:

```text
compliance/lynis/check-score.sh
```

Current minimum score:

```text
88
```

The build fails if the required score is not reached.

---

# 📥 Compliance Reports

Reports are initially generated on the temporary VM under:

```text
/tmp/golden-image-validation/
```

They are downloaded by Packer into:

```text
packer/gcp/reports/golden-image-validation/
```

Example:

```text
golden-image-validation/
├── lynis/
└── openscap/
    ├── openscap-results.xml
    └── openscap-report.html
```

GitHub Actions uploads the reports as workflow artifacts.

---

# 🧹 Image Cleanup

Before the final image is created, Packer executes:

```text
scripts/cleanup-image.sh
```

This prepares the VM for use as a reusable Golden Image.

---

#  Local GCP Build

GCP images can also be tested locally when the Google Cloud CLI is authenticated.

Check:

```bash
gcloud auth list
```

Configure:

```bash
gcloud config set project YOUR_GCP_PROJECT_ID
```

Export:

```bash
export PKR_VAR_project_id="YOUR_GCP_PROJECT_ID"
export PKR_VAR_zone="europe-west1-b"
```

Then:

```bash
cd packer/gcp
```

Initialize:

```bash
packer init .
```

Format:

```bash
packer fmt -recursive .
```

Check:

```bash
packer fmt -check -recursive .
```

Validate:

```bash
packer validate .
```

Build:

```bash
packer build .
```

---

# 🚀 GitHub Actions Build

The automated workflow is:

```text
.github/workflows/gcp-golden-image.yml
```

To start it manually:

```text
GitHub
→ Actions
→ GCP Golden Image Build
→ Run workflow
```

---

# ✅ Pipeline

A successful build executes:

```text
Checkout repository
        │
        ▼
GitHub OIDC authentication
        │
        ▼
Google Workload Identity
        │
        ▼
Packer init
        │
        ▼
Packer format check
        │
        ▼
Packer validation
        │
        ▼
Temporary GCP VM
        │
        ▼
Ansible hardening
        │
        ▼
Reboot
        │
        ▼
Ansible verification
        │
        ▼
OpenSCAP
        │
        ▼
Lynis
        │
        ▼
Compliance reports
        │
        ▼
Image cleanup
        │
        ▼
GCP Golden Image
        │
        ▼
GitHub artifact upload
```

---

# 🔎 Verify the Image

```bash
gcloud compute images list \
  --project="YOUR_GCP_PROJECT_ID" \
  --filter="name~'^ubuntu-2404-golden-'" \
  --sort-by=~creationTimestamp
```

---

#  Troubleshooting

## Cloud Resource Manager API Disabled

```text
Cloud Resource Manager API has not been used
or it is disabled
```

Fix:

```bash
gcloud services enable \
  cloudresourcemanager.googleapis.com \
  --project="$PROJECT_ID"
```

---

## Authentication Check

```bash
gcloud auth list
```

Then:

```bash
gcloud projects describe "$PROJECT_ID"
```

---

## Check Service Account Roles

```bash
gcloud projects get-iam-policy "$PROJECT_ID" \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:${SA}" \
  --format="table(bindings.role)"
```

---

## Packer Formatting Failure

Fix:

```bash
packer fmt -recursive .
```

Verify:

```bash
packer fmt -check -recursive .
```

---

# 🔐 Security Notes

Never commit:

```text
Service Account JSON keys
OAuth tokens
SSH private keys
temporary GitHub credentials
local authentication files
```

The GCP pipeline intentionally uses **Workload Identity Federation** to avoid storing permanent Google Cloud credentials.

---

# 📚 Related Documentation

➡️ [Main Project README](../../README.md)

➡️ [VirtualBox Golden Image](../virtualbox/README.md)

---

<div align="center">

### ☁️ Keyless authentication. Automated hardening. Validated cloud images.

</div>

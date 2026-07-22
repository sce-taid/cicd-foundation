<!--
Copyright 2026 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
-->

# Product Requirements: Devcontainer Integration

This document defines the architectural requirements, design standards, and validation criteria for integrating devcontainer-based development environments into the Cloud Workstations clusters and CI/CD pipelines.

---

## 1. Directory Structure Convention

To keep code repositories clean and modular, devcontainer-specific assets must be isolated inside a `.devcontainer` subfolder inside the application directory:

```
apps/my-app/
├── .devcontainer/
│   ├── devcontainer.json   <-- Configures mounting and features
│   └── Dockerfile          <-- Devcontainer-specific OS layers
├── skaffold.yaml           <-- Custom build builder config
└── ...
```

- **Dockerfile Placement**: The Dockerfile referenced by `devcontainer.json` must reside inside the `.devcontainer/` folder.
- **Build Context**: The build context declared in `devcontainer.json` must point to the application root directory (`"context": ".."`), allowing the container to copy files from the application root during the build.

---

## 2. Infrastructure-as-Code Configuration (Terraform)

The custom workstation image triggers are managed declaratively in `terraform.tfvars` inside the `cws_custom_images` variable:

- **Skaffold Integration**: The configuration must map to the application directory containing the `skaffold.yaml` file (`build.skaffold_path`).
- **Dynamic Builder Sizing**: Developers can customize the build runner size (e.g. `E2_HIGHCPU_32` for fast compilation) using the `build.machine_type` attribute.

---

## 3. Secret Management & Secure Mounts

If the devcontainer requires private access tokens (e.g., GitHub packages, internal repositories) at compile time:

- **Secret Manager Reference**: Environment variables in `terraform.tfvars` can reference Google Cloud Secret Manager secrets using the prefix `sm://` (e.g., `GITHUB_TOKEN = "sm://my-github-token"`).
- **Automatic Bindings**: The Terraform module must automatically convert these `sm://` values into native `secret_env` parameters in the Cloud Build trigger.
- **No Disk Persistence**: Secrets must only be exposed as transient environment variables in memory during step execution, and must never be baked into container layers or saved to disk.

---

## 4. Build Caching and Performance

To ensure builds are fast and do not cause performance regressions:

- **BuildKit Registry Caching**: All custom devcontainer builds must use the custom `build_devcontainer` wrapper script.
- **Automatic Cache Tags**: The script must automatically derive a cache reference tag (appending `-cache` to the repository target) and export caching layers directly to Artifact Registry via BuildKit:
  ```bash
  --cache-from type=registry,ref=${IMAGE}-cache
  --cache-to type=registry,ref=${IMAGE}-cache,mode=max
  ```

---

## 5. Secure VPC-SC & Offline Runtime Access

For workstations deployed in secure, air-gapped environments under VPC Service Controls (VPC-SC) or using open-source editors like CodeOSS:

- **Pre-packaged CLI Tooling**: The base workstation GNOME image must pre-package Node.js, NPM, and the MIT-licensed `@devcontainers/cli` globally at compile time.
- **No Dynamic Downloads**: The workstation must not require an active internet connection to download devcontainer helpers or pull CLI packages dynamically from npmjs.org.
- **Offline Execution**: The pre-installed CLI must support executing local build/run tasks entirely within the VPC-SC perimeter, provided target base images are pre-cached in the local Artifact Registry.

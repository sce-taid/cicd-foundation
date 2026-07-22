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

# User Guide: Devcontainer Support for Cloud Workstations & CI

This guide explains how to use the newly implemented devcontainer support in the `cicd-foundation` repository. You can now build developer workstation images directly from a `.devcontainer/devcontainer.json` file using the node-based devcontainer CLI integrated into the CI/CD pipeline, and map these images to your Cloud Workstations (CWS) configurations.

---

## 1. Project Structure Convention

By convention, all development-specific configurations, including the development-specific `Dockerfile`, are encapsulated inside the `.devcontainer/` folder. This keeps the root directory clean and separates development environments from production configurations.

```
apps/
└── my-workstation-app/
    ├── .devcontainer/
    │   ├── devcontainer.json   <-- References the local Dockerfile
    │   └── Dockerfile          <-- Devcontainer-specific setup
    ├── skaffold.yaml           <-- Skaffold build driver
    └── ...
```

In this setup, your `devcontainer.json` should reference the local Dockerfile using relative paths and configure the build context to point to the application root directory:

```json
{
  "name": "My Dev Environment",
  "build": {
    "dockerfile": "Dockerfile",
    "context": ".."
  }
}
```

---

## 2. Skaffold Configuration (`skaffold.yaml`)

To build the image using the devcontainer CLI, configure your `skaffold.yaml` to use a **Custom Builder**. Skaffold will pass the calculated target tag (including the registry path and hash) via the `$IMAGE` environment variable.

Create a `skaffold.yaml` in your application folder:

```yaml
apiVersion: skaffold/v3
kind: Config
metadata:
  name: my-workstation-app
build:
  artifacts:
    - image: my-workstation-image
      custom:
        # Use the platform wrapper script to build and automatically cache the layers
        buildCommand: build-devcontainer $IMAGE
```

---

## 3. CWS Config Mapping (Terraform)

In your `terraform.tfvars`, define the custom image using the existing `cws_custom_images` schema.
The module automatically detects if there are workstation apps and configures the CI/CD pipeline.

```hcl
cws_custom_images = {
  "my-workstation" = {
    git_repo = {
      url    = "https://github.com/my-org/my-repo.git"
      branch = "main"
    }
    build = {
      # Path to the directory containing the skaffold.yaml and .devcontainer/
      skaffold_path = "apps/my-workstation-app"
      machine_type  = "E2_HIGHCPU_32" # Custom builder machine size
    }
  }
}

cws_configs = {
  "developer-workstation-config" = {
    cws_cluster        = "my-cws-cluster"
    custom_image_names = ["my-workstation"] # Maps the built devcontainer image to this workstation
    machine_type       = "e2-standard-4"
  }
}
```

---

## 4. Environment Variables & Secret Manager Integration

If your devcontainer needs private tokens (e.g. to pull private features or authenticate git) at build time, you can reference secrets stored in Google Cloud Secret Manager using the `sm://` prefix.

### Step 1: Configure Secret in Terraform

In your `terraform.tfvars`, pass the Secret Manager URI inside the `build.env` map:

```hcl
cws_custom_images = {
  "my-workstation" = {
    # ...
    build = {
      skaffold_path = "apps/my-workstation-app"
      env = {
        # Formats supported:
        # 1. Full resource path:
        #    sm://projects/PROJECT_ID/secrets/SECRET_NAME/versions/VERSION
        # 2. Local project, specific version:
        #    sm://SECRET_NAME/VERSION
        # 3. Local project, latest version (Recommended):
        #    sm://my-github-token
        GITHUB_TOKEN = "sm://my-github-token"
      }
    }
  }
}
```

The Terraform module will automatically configure the Cloud Build trigger to fetch the secret and expose it as a native `secret_env` variable.

### Step 2: Consume Secret in Skaffold Build

Modify the `buildCommand` in your `skaffold.yaml` to run a script or pass the environment variable to the CLI:

```yaml
build:
  artifacts:
    - image: my-workstation-image
      custom:
        buildCommand: |
          # The helper script automatically inherits any secret_env variables (like $GITHUB_TOKEN)
          build-devcontainer $IMAGE
```

---

## 5. Build Performance & Caching (Automated)

The CI/CD pipeline is pre-configured to use **BuildKit registry-based caching** automatically when using the platform wrapper script `build-devcontainer`.

- **How it works**: The helper script automatically derives a cache tag (appending `-cache` to your registry target image) and configures the build to pull and push layers directly to/from Artifact Registry:
  ```bash
  --cache-from type=registry,ref=${IMAGE}-cache
  --cache-to type=registry,ref=${IMAGE}-cache,mode=max
  ```
- **Result**: Successive builds only rebuild modified layers or devcontainer features, drastically speeding up compilation times without requiring any local filesystem storage or GCS buckets.

---

## 6. Offline / Secure VPC-SC Devcontainer CLI Access

For workstations deployed in secure, air-gapped environments under VPC Service Controls (VPC-SC) or using open-source editors like CodeOSS:

- **Pre-installed Tooling**: The base GNOME workstation image pre-packages Node.js, NPM, and the MIT-licensed `@devcontainers/cli` globally at build time.
- **Execution**: You can invoke the CLI helper directly in any workstation terminal without needing a public internet connection or dynamic NPM downloads:
  ```bash
  devcontainer --help
  ```
- **Offline Mode**: Since the CLI is baked in, you can run nested container tasks (such as `devcontainer up --workspace-folder .`) entirely offline, provided your base container images are pre-cached or hosted inside your peered Artifact Registry.

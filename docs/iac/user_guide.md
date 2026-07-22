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

# User Guide: Application Registration & Pipeline Configuration

This guide describes how to register applications, custom workstations, and devcontainer environments in the `cicd-foundation` repository, detailing runtime options and automation schedules.

---

## 0. Local Developer Setup & Prerequisites

Before committing changes or deploying resources, developers must configure their local environment with the following dependencies.

### 0.1 Required Command-Line Tools

1.  **`uv`** (Python Workspace Manager):
    - Used to run isolated Python unit tests and execute script environments.
    - Install it globally using `pipx`:
      ```bash
      pipx install uv
      ```
    - _(Ensure local bin is in your path by running `pipx ensurepath` and restarting your shell)._
2.  **`pre-commit`** (Hooks Framework):
    - Runs code quality checks, keep-sorted checks, and license verification before commits are recorded.
    - Install it globally using pipx or your package manager:
      ```bash
      pipx install pre-commit
      ```
3.  **`bats`** (Bash Automated Testing System):
    - Required to execute workstation shell-layer integration tests.
    - Install via system packages:
      ```bash
      # Debian/Ubuntu
      sudo apt-get install bats
      ```

### 0.2 Initial Workspace Bootstrapping

Once the dependencies are installed on your host workstation, run the following commands to initialize the repository hooks:

```bash
# 1. Install pre-commit hooks
pre-commit install

# 2. Run a full validation check across all files
pre-commit run --all-files
```

This guarantees that all linter rules, formatting configurations, and unit tests execute successfully in your local environment.

---

## 1. Application Registration Model

Applications are registered in your `terraform.tfvars` file under the `apps` map block.

### 1.1 Configuration Schema Reference

Each entry under `apps` supports the following settings:

```hcl
apps = {
  "app-name" = {
    # [Optional] Deployment runtime target. Options: "cloudrun", "gke", "workstations", or null
    runtime = null

    # Build parameters
    build = {
      # Path to the folder containing skaffold.yaml relative to repo root
      skaffold_path = "apps/my-app"
      # [Optional] Timeout for the build (seconds)
      timeout_seconds = 1800
      # [Optional] GCP Machine type for the builder (e.g. "E2_HIGHCPU_32")
      machine_type = "E2_HIGHCPU_32"
      # [Optional] Environment variables passed to the custom builder
      env = {}
    }

    # [Optional] Cloud Scheduler custom configuration
    workstation_config = {
      # Cron schedule (defaults to daily "0 1 * * *")
      ci_schedule = "0 2 * * *"
      # Overrides default paused state (true/false)
      paused = true
    }
  }
}
```

---

## 2. Runtimes & Deployment Modes

The `runtime` parameter determines the automated actions executed upon a code push:

| Runtime Value           | Trigger Target       | CD Deployment   | Default Rebuild Schedule | Use Case                                    |
| :---------------------- | :------------------- | :-------------- | :----------------------- | :------------------------------------------ |
| **`"cloudrun"`**        | Cloud Build + Deploy | Yes (Cloud Run) | **Paused**               | Standard stateless microservices            |
| **`"gke"`**             | Cloud Build + Deploy | Yes (GKE)       | **Paused**               | Kubernetes cluster services                 |
| **`"workstations"`**    | Cloud Build Only     | No              | **Active (Unpaused)**    | Automated developer base workstation layers |
| **`null` (or omitted)** | Cloud Build Only     | No              | **Paused**               | Build-only templates, DevContainers         |

---

## 3. DevContainers / Build-Only (CI-Only) Configuration

If you only want to compile and store container images (such as developer devcontainer templates) without running CD releases, configure the app with no `runtime`.

For a detailed walkthrough on setting up a devcontainer image (including folder structure conventions and BuildKit caching), see the 👉 [Devcontainer User Guide](../devcontainers/user_guide.md).

### Step 1: Configure `terraform.tfvars`

Omit the `runtime` parameter so it defaults to `null`:

```hcl
apps = {
  "devcontainer-node-demo" : {
    build = {
      skaffold_path = "apps/devcontainers/node-demo"
    }
  }
}
```

### Step 2: Configure `skaffold.yaml`

Point skaffold to use the devcontainer build-runner by adding a custom builder:

```yaml
apiVersion: skaffold/v3
kind: Config
metadata:
  name: devcontainer-node-demo
build:
  artifacts:
    - image: devcontainer-node-demo-image
      custom:
        buildCommand: build-devcontainer $IMAGE
```

---

## 4. Rebuild Automation (Cloud Scheduler)

Every application gets a Cloud Scheduler job created automatically.

- **Workstations**: The rebuild scheduler defaults to **active** to regularly pull security updates and keep workstation layers fresh.
- **Others / Build-Only**: Rebuild schedulers default to **paused**. You can unpause them via the GCP Console or by setting `paused = false` inside `workstation_config`:

```hcl
apps = {
  "devcontainer-node-demo" : {
    build = { skaffold_path = "apps/devcontainers/node-demo" }
    workstation_config = {
      paused = false # Automatically build every night
    }
  }
}
```

---

## 5. Security & Build Secrets

If your custom build commands need build-time secrets (like GitHub tokens or private SSH keys), you can map GCP Secret Manager resources directly:

```hcl
apps = {
  "devcontainer-node-demo" : {
    build = {
      skaffold_path = "apps/devcontainers/node-demo"
      env = {
        # Fetch the latest version of 'my-github-token' from Secret Manager
        GITHUB_TOKEN = "sm://my-github-token"
      }
    }
  }
}
```

The pipeline automatically converts the secret reference to a Cloud Build `secret_env` binding, keeping secrets out of build configuration logs.

---

## 6. AI Agentic SDLC & Automated Reviews

The platform supports executing automated, multi-persona AI agents during the codebase's lifecycle phases (such as pre-build code reviews).

To configure automated code and security audits using autonomous agents connected to the GCP Skill Registry, see the dedicated 👉 [**AI Agentic SDLC & Skill Registry Guide**](../agentic_sdlc/user_guide.md) for full instructions on configuring agents, writing custom skills, and executing local tests.

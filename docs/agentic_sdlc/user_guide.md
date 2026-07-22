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

# AI Agentic SDLC Integration Guide

This guide explains how to configure, customize, and extend automated agentic engineering loops in your CI/CD pipelines.

---

## 1. Concept: Agentic SDLC

Traditionally, CI/CD pipelines run static checks (linters, unit tests, vulnerability scanners). With the **Gemini Enterprise Agent Platform (GEAP)** and **Antigravity SDK / ADK**, you can insert autonomous, reasoning-capable AI agents into these pipelines to perform dynamic, cognitive engineering tasks.

The default pipeline supports a pre-build **Multi-Persona Code & Security Review** hook. Before compiling container images, an agent cloned into the code workspace adopts multiple developer and reviewer roles (SWE, Security, SRE) sequentially to audit the code changes, compile feedback, and flag issues.

```
                  ┌────────────────────────────────────────┐
                  │          GCP Skill Registry            │
                  │   ┌─────────────┐       ┌──────────┐   │
                  │   │  persona-swe│       │persona-  │   │
                  │   └──────┬──────┘       │ security │   │
                  └──────────┼──────────────└────┬─────┘───┘
                             │ Query             │ Query
                             ▼                   ▼
┌──────────────┐      ┌─────────────┐      ┌─────────────┐      ┌──────────────┐
│  git clone   ├─────►│ SWE Review  ├─────►│ Sec Audit   ├─────►│ docker build │
└──────────────┘      └─────────────┘      └─────────────┘      └──────────────┘
```

---

## 2. Configuration Schema

You enable agents by declaring the `agents` block in your application map in `terraform.tfvars`:

```hcl
apps = {
  "devcontainer-node-demo" = {
    build = {
      skaffold_path = "apps/devcontainers/node-demo"
    }

    # Configure agentic hooks
    agents = {
      "pre-build" = {
        "review" = {
          enabled       = true
          model         = "gemini-3.5-flash"  # Gemini Model for inference
          personas      = ["swe", "security"] # Personas to execute
          allow_failure = true                # Set to false to fail build on warnings
        }
      }
    }
  }
}
```

### Configuration Variables

You can configure global defaults at the blueprint level in `terraform.tfvars`:

| Variable                       | Type           | Description                                               | Default                                           |
| :----------------------------- | :------------- | :-------------------------------------------------------- | :------------------------------------------------ |
| `default_agentic_model`        | `string`       | The Gemini model used for the execution loop.             | `"gemini-3.5-flash"`                              |
| `default_agentic_location`     | `string`       | The Agent Platform endpoint location for the models.      | `"global"`                                        |
| `default_agentic_personas`     | `list(string)` | Personas to run sequentially in the review.               | `["swe", "security"]`                             |
| `default_agentic_instructions` | `string`       | The base system instructions defining the agent behavior. | `"You are an automated platform review agent..."` |
| `default_agentic_prompt`       | `string`       | The task instructions prompt passed to the agent.         | `"Analyze the modified files..."`                 |

---

## 3. Skill Provisioning & GCP Skill Registry

Skills extend an agent's reasoning capability. A skill is a self-contained ZIP archive containing a standard `SKILL.md` instruction file, optional script files, and reference documentation.

### 3.1 Registrating Shared Skills (GCP Skill Registry)

To register a shared, organizational skill, upload the packaged ZIP to the GCP Skill Registry of your project. As the Skill Registry resource is currently in Preview, this is typically done via:

1.  **Agent Platform Studio UI**: Open the Google Cloud Console, navigate to **Agent Platform > Studio > Skills**, and upload your ZIP package.
2.  **REST API / Python SDK**: Programmatically publish skills during environment bootstrapping.

The zip file must contain `SKILL.md` at the root level, formatted with YAML frontmatter:

```markdown
---
name: persona-security
description: Security compliance auditor persona for pipeline validations
license: Apache-2.0
---

# Security Persona Instructions

- Audit the repository workspace for exposed credentials or service account JSON keys.
- Ensure that Kubernetes manifests do not allow running as root.
- Highlight any insecure open ports in Cloud Run or GKE configurations.
```

### 3.2 Dynamic Orchestration (The Runner)

When the build trigger runs, the pipeline executes `agentic_runner.py` inside the `build-runner` container. The runner utilizes a **Coordinator-Delegate Parallel Orchestrator** pattern powered by the **Agent Development Kit (ADK)**:

```python
import asyncio
from google.antigravity import Agent, LocalAgentConfig

# 1. Specialist task triggered concurrently via asyncio.gather
async def run_persona(persona, prompt, model_name, project_id, location):
    config = LocalAgentConfig(
        model=model_name,
        vertex=True,
        project=project_id,
        location=location,
        system_instructions=f"You adopt the '{persona}' persona and audit codebase changes.",
        skills_paths=["skills/"]
    )
    agent = Agent(config)
    async with agent:
        response = await agent.chat(prompt)
        return await response.text()

# 2. Main orchestration gathering results
async def main():
    # Concurrent specialist executions
    tasks = [
        run_persona(p, prompt, model_name, "my-project", "us-central1")
        for p in ["swe", "security"]
    ]
    reports = await asyncio.gather(*tasks)

    # 3. Consolidation agent synthesizes all reports
    orchestrator_config = LocalAgentConfig(
        model=model_name,
        vertex=True,
        project="my-project",
        location="us-central1",
        system_instructions="Synthesize raw reviews into a single executive Markdown report.",
        skills_paths=["skills/"]
    )
    orchestrator = Agent(orchestrator_config)
    async with orchestrator:
        final_summary = await orchestrator.chat(str(reports))
        print(await final_summary.text())
```

During execution, specialists run concurrently (saving execution time), and the coordinator synthesizes their findings into an executive markdown summary that details blockers, warnings, and enhancements.

---

## 4. Writing Repository-Local Skills

In addition to shared registry skills, you can write project-specific skills directly in the repository:

1.  Create a folder `skills/<skill-name>/` in your codebase root.
2.  Add a `SKILL.md` file declaring its metadata frontmatter and instructions.
3.  The agent will automatically scan the workspace and load these local skills during the pre-build phase.

---

## 5. Security & Access Control

To comply with the principle of least privilege, IAM permissions are configured dynamically:

- **Conditional IAM Allocation**: The Terraform module evaluates if any registered app has `agents.pre-build.review.enabled` set to `true`.
- **Automatic Bindings**: If active, the module automatically binds the role **Agent Platform User (`roles/aiplatform.user`)** to the Cloud Build service account. This allows the runner to interact with Gemini models and query the GCP Skill Registry. If agent hooks are disabled, this permission is not granted.

---

## 6. Local Development and Testing with `uv`

To keep development environments isolated and standard across both developers and workstations, we adopt **`uv`** as the Python packaging and workspace manager.

### 6.1 Prerequisites

Ensure `uv` is installed on your workstation. It is recommended to install it globally using `pipx`:

```bash
pipx install uv
```

_(If `~/.local/bin` is not in your PATH, run `pipx ensurepath` to configure your shell environment)._

### 6.2 Running Tests Locally

All Python-based agent triggers (like `agentic_runner.py`) contain unit tests located in their respective `tests/` folders. Rather than setting up virtualenvs manually, use `uv run`:

```bash
# Runs the full unit test suite under an isolated virtual environment
uv run --group dev pytest infra/modules/cicd_pipelines/tests/

# Run tests with coverage tracking
uv run --group dev pytest --cov=infra/modules/cicd_pipelines/scripts/ infra/modules/cicd_pipelines/tests/
```

`uv` reads the dependencies and dev toolgroups from the root `pyproject.toml`, caches downloads, and runs the command instantly inside the isolated `.venv` folder.

---

## 7. Extending Pipelines with Custom Workspace Agents

For advanced workflows, developers can bypass the default multi-persona review orchestrator and write their own custom Antigravity SDK agent execution script.

### 7.1 How Discovery Works

During the `agentic-pre-build-review` phase, the runner automatically scans the application's workspace directory for a script at the path:
`<application_directory>/.agentic/review.py`

- **Custom Script Found**: The runner executes it using `/usr/bin/python3`, allowing you to run arbitrary agentic loops or custom reviews.
- **No Custom Script Found**: The runner falls back to the default multi-persona parallel reviews defined in `terraform.tfvars`.

This dynamic discovery requires **zero infrastructure changes** or Terraform redeployments.

### 7.2 Writing a Custom Agent Script

Place your script at `<your-app-dir>/.agentic/review.py`. Below is an example of a custom codebase auditor using the `google.antigravity` SDK:

```python
#!/usr/bin/env python3
import os
import sys
from google.antigravity import Agent, LocalAgentConfig

# Base instructions and prompt defaults for the audit agent
AUDIT_AGENT_INSTRUCTIONS = (
    "You are a specialized performance audit agent. Review the modified "
    "codebase changes and flag any performance bottlenecks, unnecessary "
    "loops, or sub-optimal database queries."
)

DEFAULT_AGENT_PROMPT = "Audit the workspace files."


async def main():
    # Read Cloud Build injected environment configurations
    project_id = os.environ.get("GCP_PROJECT")
    location = os.environ.get("GCP_LOCATION")
    model_name = os.environ.get("AGENT_MODEL")
    prompt = os.environ.get("AGENT_PROMPT", DEFAULT_AGENT_PROMPT)

    if not model_name:
        print("ERROR: AGENT_MODEL environment variable is not set.", file=sys.stderr)
        sys.exit(1)

    # Configure a custom agent with local instructions
    config = LocalAgentConfig(
        model=model_name,
        vertex=True,
        project=project_id,
        location=location,
        system_instructions=AUDIT_AGENT_INSTRUCTIONS,
        skills_paths=["skills/"]
    )

    # Execute the audit chat loop
    agent = Agent(config)
    async with agent:
        response = await agent.chat(prompt)
        print("\n=== Custom Performance Audit Report ===")
        print(await response.text())
        print("=======================================")

if __name__ == "__main__":
    import asyncio
    asyncio.run(main())
```

Make sure to check the script into your git repository.

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

# Product Requirements: AI Agentic SDLC & Skill Integration

This document defines the functional requirements and security policies governing the integration of autonomous engineering review loops inside the CI/CD pipeline triggers.

---

## 1. Automated Execution Gating

- **Pre-build Execution**: Review hooks must execute immediately after the source code workspace is cloned and **before** Skaffold compilation begins.
- **Result Persistence**: Review summaries must be written to standard stdout/stderr logs and compiled into a single executive Markdown report (`report.md`) uploaded directly to the pipeline's GCS bucket.
- **Fail-Open / Fail-Closed**: Triggers must support the `allow_failure` toggle:
  - `allow_failure = true` (Fail-Open): Agent warnings and lint feedback are logged, but the build compiles successfully.
  - `allow_failure = false` (Fail-Closed): Any critical blocker flagged by a review persona immediately terminates the trigger run with a non-zero exit status, blocking compilation.

---

## 2. Configurable Specialist Personas

The system must support running multiple review personas sequentially or concurrently:

- **Standard Personas**:
  - `swe`: Codebase style, refactoring, and logical correctness review.
  - `security`: Auditing exposed secrets, insecure ports, and privilege escalations.
  - `sre`: Systemd files validity, recovery configurations, and performance bottleneck scanning.
- **Instructions Override**: Trigger properties must allow overriding system instructions and execution prompts per application trigger.

---

## 3. Dynamic IAM Governance

To protect sensitive Vertex AI resources and GCP services:

- **Least Privilege**: The Cloud Build service account must only be granted the **Agent Platform User (`roles/aiplatform.user`)** role if one or more registered applications actively enable `agents.pre-build.review.enabled`.
- **Automated Binding**: The Terraform orchestration module must calculate this dependency dynamically using an `anytrue` check at apply-time, requiring no manual IAM intervention.

---

## 4. Skill Registration and Formatting

- **Standard Compliance**: All repository-local or organization-shared skills must follow the standard `agentskills.io` format.
- **YAML Frontmatter**: The instruction file `SKILL.md` must declare metadata (name, description, license) on lines 1-12.
- **Testing Gating**: Any modifications to a `SKILL.md` file must be verified by running the `validate_skill.bats` test suite, guaranteeing zero syntax regressions before deployment.

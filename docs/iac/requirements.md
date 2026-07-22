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

# Requirements: CI/CD Pipelines & Automation

This document defines the functional requirements for the IaC-delivered CI/CD pipelines, Cloud Build triggers, deployment targets, and automated image maintenance schedules.

---

## 1. CI/CD Orchestration (Triggers & Releases)

- **FR-PIPE-1: Source-Driven Triggers**:
  - Triggers must support GitHub Webhooks, manual activation, or Secure Source Manager (SSM) Git repository webhooks.
- **FR-PIPE-2: Automated Cloud Deploy Releases**:
  - For applications with a runtime explicitly configured as `"cloudrun"` or `"gke"`, the CI/CD pipeline must automatically create a Google Cloud Deploy release to progress deployment across stages.
- **FR-PIPE-3: Build-Only Mode (CI-Only)**:
  - If no `runtime` is specified for an application (or if it is set to `null`), the pipeline must build and tag the container image but **not** trigger a Cloud Deploy pipeline.

---

## 2. Rebuild Automation (Cloud Scheduler)

- **FR-SCHED-1: Rebuild Trigger Generation**:
  - Every registered application (whether build-only, workstation, GKE, or Cloud Run) must receive a dedicated **Cloud Scheduler** job to automate periodic image rebuilds.
- **FR-SCHED-2: Workstation Rebuild Active Defaults**:
  - If the application is a custom workstation image (`runtime = "workstations"`), the Cloud Scheduler job must be **active (unpaused)** by default to ensure upstream OS patches are automatically compiled.
- **FR-SCHED-3: Conditional Idle Pausing**:
  - If the application does not have a runtime configured (`null`) or uses standard deployment targets (`"cloudrun"`, `"gke"`), the Cloud Scheduler job must be **paused** by default to prevent idle resource consumption.

---

## 3. Compliance & Security (Binary Authorization)

- **FR-SEC-1: Vulnerability Auditing and Signing**:
  - The build runner must execute a Kritis Signer step to audit container images and sign them using a KMS key if they comply with the configured vulnerability policies.
- **FR-SEC-2: Attestation Enforcement**:
  - Google Cloud Deploy and Cloud Workstations configurations must enforce Binary Authorization policies, rejecting unsigned container images.

---

## 4. AI Agentic SDLC & Automated Reviews

- **FR-AGENT-1: Multi-Persona Pre-Build Reviews**:
  - The pipeline must support running automated codebase reviews using multiple persona agents (e.g. SWE, SRE, Security) sequentially in the `pre-build` phase (after code cloning, but before compiling images).
- **FR-AGENT-2: Skill Registry Integration**:
  - Agents must be powered by the official Antigravity ADK, querying the **GCP Skill Registry** dynamically to resolve their persona capabilities.
- **FR-AGENT-3: Lifecycle Phase Grouping**:
  - Agent tasks must be structured within application configurations under phase-specific directories (e.g., `pre-build`, `post-build`) to support generic SDLC lifecycle integration.
- **FR-AGENT-4: Automated Least-Privilege IAM**:
  - The Terraform module must automatically detect when agentic workflows are enabled and bind the Agent Platform User role (`roles/aiplatform.user`) to the Cloud Build service account.
- **FR-AGENT-5: Custom Developer Workspace Agents**:
  - The pre-build review runner must support runtime extensibility: if a developer checks in a custom agent script under the path `<app-dir>/.agentic/review.py`, the pipeline must execute this script instead of the default multi-persona review.

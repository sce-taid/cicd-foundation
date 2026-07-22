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

# Requirements: Cloud Workstations Custom Images (GNOME Remote Desktop)

This document defines the functional and non-functional requirements for the custom Workstations container images managed by the platform.

---

## 1. Functional Requirements

- **FR-CWS-1: Headless GNOME Desktop**: The container must run a headless Wayland/X11 GNOME session.
- **FR-CWS-2: Browser-Based Access (RDP)**: The workstation must expose a secure RDP server accessible via standard web browsers (using Apache Guacamole as a gateway).
- **FR-CWS-3: Ephemeral Credentials**: RDP login credentials must be generated dynamically per-start, injected at runtime, and never persisted to storage.
- **FR-CWS-4: Systemd Service Orchestration**: All daemon services inside the container (e.g., Guacamole, Nginx, Gnome Remote Desktop) must be orchestrated natively using systemd.

---

## 2. Non-Functional Requirements

### 2.1 Performance

- **Startup Latency**: The remote desktop session must be reachable and ready for connection within **200 seconds** of container startup (for 99.9% of launches using recommended hardware configurations).

### 2.2 Reliability

- **Service Initialization SLO**: The core container services (Nginx, Guacamole, GNOME) must achieve a **99.9% success rate** for initialization post-container start.
- **Observability**: Service starts and initialization failures must be logged directly to Google Cloud Logging.

### 2.3 Security

- **Software Rendering Enforcement**: Workstation containers must run with `LIBGL_ALWAYS_SOFTWARE=1` to ensure stable desktop graphics rendering across all CPU-only Google Cloud Workstations machine types.

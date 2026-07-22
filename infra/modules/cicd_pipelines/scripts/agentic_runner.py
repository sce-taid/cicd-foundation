#!/usr/bin/env python3

# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Agentic SDLC pre-build review runner.

Orchestrates parallel reviews by specialist persona agents (e.g., security, UX, SRE)
and consolidates their reports into a unified Markdown summary for developers.
"""

import asyncio
import os
import sys

from google.antigravity import Agent, LocalAgentConfig

# System instruction templates for the audit personas and orchestrator
AUDITOR_PERSONA_INSTRUCTION_TEMPLATE = (
    "You are a repository auditor adopting the '{persona}' persona. "
    "Review the codebase changes and provide a structured, professional audit report."
)

ORCHESTRATOR_INSTRUCTION = (
    "You are a lead orchestrator agent. You receive raw review reports from various persona specialists. "
    "Synthesize them into a single, clean, executive-level Markdown summary. Group findings by severity "
    "(Blockers, Warnings, Enhancements) and indicate which persona raised each point. Ensure any critical "
    "vulnerability or styling issues are highlighted at the top."
)

STANDARD_REVIEW_INSTRUCTION = "You are an automated platform review agent. Audit the workspace codebase changes."

# Rate limit mitigation settings
DEFAULT_RATE_LIMIT_DELAY = 1.0
DEFAULT_AGENT_TIMEOUT = 180.0

try:
    RATE_LIMIT_DELAY_SECONDS = float(os.environ.get("AGENT_RATE_LIMIT_DELAY"))
except (TypeError, ValueError):
    RATE_LIMIT_DELAY_SECONDS = DEFAULT_RATE_LIMIT_DELAY

try:
    AGENT_TIMEOUT_SECONDS = float(os.environ.get("AGENT_TIMEOUT"))
except (TypeError, ValueError):
    AGENT_TIMEOUT_SECONDS = DEFAULT_AGENT_TIMEOUT


async def run_persona_agent_with_delay(
    delay: float, persona: str, prompt: str, model_name: str, project_id: str, location: str
):
    """Executes run_persona_agent after a specified startup delay to prevent burst limits."""
    if delay > 0:
        await asyncio.sleep(delay)

    try:
        # Enforce a circuit-breaker timeout on the agent audit call
        return await asyncio.wait_for(
            run_persona_agent(persona, prompt, model_name, project_id, location), timeout=AGENT_TIMEOUT_SECONDS
        )
    except asyncio.TimeoutError:
        print(
            f"WARNING: Audit for persona '{persona}' timed out after {AGENT_TIMEOUT_SECONDS} seconds.", file=sys.stderr
        )
        return persona, f"ERROR: Audit execution timed out after {AGENT_TIMEOUT_SECONDS} seconds."
    except Exception as e:
        print(f"WARNING: Audit for persona '{persona}' failed: {e}", file=sys.stderr)
        return persona, f"ERROR: Audit execution failed: {e}"


# Helper function to run a single persona agent
async def run_persona_agent(persona: str, prompt: str, model_name: str, project_id: str, location: str):
    """Executes a review using a specific repository auditor persona.

    Args:
        persona: The name of the persona to adopt (e.g., "security", "sre").
        prompt: The review instructions and input context.
        model_name: The name of the Agent Platform model to invoke.
        project_id: The Google Cloud project hosting Agent Platform.
        location: The region location for the Agent Platform endpoint.

    Returns:
        A tuple of (persona, report_text) containing the review result.
    """
    instruction = AUDITOR_PERSONA_INSTRUCTION_TEMPLATE.format(persona=persona)

    config = LocalAgentConfig(
        model=model_name,
        vertex=True,
        project=project_id,
        location=location,
        system_instructions=instruction,
        skills_paths=["skills/"],
    )

    agent = Agent(config)
    async with agent:
        response = await agent.chat(prompt)
        report_text = await response.text()
        return persona, report_text


async def main():
    """Main entrypoint for the pre-build review orchestration.

    Reads environment configuration, runs all requested persona auditor reviews
    concurrently, and consolidates the specialists findings into a unified report.
    """
    # Check for custom agent review script in the application workspace
    workspace_dir = os.environ.get("SKAFFOLD_PATH", ".")
    custom_agent_path = os.path.join(workspace_dir, ".agentic", "review.py")
    if os.path.exists(custom_agent_path):
        print("==================================================")
        print(f" Found custom agent review script at: {custom_agent_path}")
        print(" Executing custom codebase audit...")
        print("==================================================")
        # SEC-01 Compliance: If running as root (e.g. in Cloud Build), sandbox the untrusted hook
        # inside a network-gated namespace and run under the unprivileged 'nobody' user.
        if os.getuid() == 0:
            print(" Running custom audit in network-gated sandbox (unshare + runuser nobody)...")
            cmd = ["unshare", "-n", "runuser", "-u", "nobody", "--", "python3", custom_agent_path]
        else:
            print(" Running custom audit in standard user space (unprivileged local mode)...")
            cmd = ["python3", custom_agent_path]

        process = await asyncio.create_subprocess_exec(*cmd)
        await process.wait()
        sys.exit(process.returncode)

    # Read configuration from environment variables passed by Cloud Build
    project_id = os.environ.get("GCP_PROJECT")
    location = os.environ.get("MODEL_LOCATION") or os.environ.get("GCP_LOCATION")
    model_name = os.environ.get("AGENT_MODEL")
    personas_str = os.environ.get("AGENT_PERSONAS", "")
    prompt = os.environ.get("AGENT_PROMPT", "Review the workspace changes.")

    if not project_id:
        print("ERROR: GCP_PROJECT environment variable is not set.", file=sys.stderr)
        sys.exit(1)

    if not location:
        print("ERROR: Neither MODEL_LOCATION nor GCP_LOCATION environment variables are set.", file=sys.stderr)
        sys.exit(1)

    if not model_name:
        print("ERROR: AGENT_MODEL environment variable is not set.", file=sys.stderr)
        sys.exit(1)

    personas = [p.strip() for p in personas_str.split() if p.strip()]

    # Discover modified files in the git workspace to guide the specialists audits
    changed_files = []
    try:
        # Check if we are inside a git repository
        git_check = await asyncio.create_subprocess_exec(
            "git",
            "rev-parse",
            "--is-inside-work-tree",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        await git_check.communicate()
        if git_check.returncode == 0:
            # First try comparing against HEAD~1 (typical commit push)
            git_diff = await asyncio.create_subprocess_exec(
                "git",
                "diff",
                "--name-only",
                "HEAD~1",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            stdout, _ = await git_diff.communicate()
            if git_diff.returncode != 0:
                # Fallback to unstaged changes comparison if HEAD~1 fails (e.g. single-commit repo)
                git_diff = await asyncio.create_subprocess_exec(
                    "git",
                    "diff",
                    "--name-only",
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE,
                )
                stdout, _ = await git_diff.communicate()

            changed_files = [f.strip() for f in stdout.decode().split("\n") if f.strip()]
    except Exception as e:
        print(f"Warning: Failed to discover modified files via git: {e}", file=sys.stderr)

    if changed_files:
        print(f" Detected {len(changed_files)} modified files in workspace.")
        prompt += "\n\nThe following files were modified in this change. Focus your audit on these files:\n"
        prompt += "\n".join(f"- {f}" for f in changed_files)
    else:
        print(" No modified files detected via git. Auditing entire workspace...")

    print("==================================================")
    print(" Starting Parallel Orchestrated Agentic SDLC Run  ")
    print(f" Model:        {model_name}")
    print(f" Location:     {location}")
    print(f" Personas:     {', '.join(personas) if personas else 'None'}")
    print("==================================================")

    # If no personas are specified, run a standard single agent review
    if not personas:
        print("No personas specified. Running standard single agent review...")
        config = LocalAgentConfig(
            model=model_name,
            vertex=True,
            project=project_id,
            location=location,
            system_instructions=STANDARD_REVIEW_INSTRUCTION,
            skills_paths=["skills/"],
        )
        agent = Agent(config)
        async with agent:
            response = await agent.chat(prompt)
            print("\n--- Agent Execution Output ---")
            print(await response.text())
            print("-------------------------------")
        sys.exit(0)

    # Trigger persona reviews concurrently with a staggered startup delay to mitigate rate limiting (429)
    print(f"Launching staggered parallel reviews for personas: {', '.join(personas)}...")
    tasks = [
        run_persona_agent_with_delay(i * RATE_LIMIT_DELAY_SECONDS, p, prompt, model_name, project_id, location)
        for i, p in enumerate(personas)
    ]
    results = await asyncio.gather(*tasks)

    # Formulate individual reports into a single prompt for consolidation
    individual_reports = ""
    for persona, report in results:
        individual_reports += f"\n=== REVIEW REPORT FOR PERSONA: {persona} ===\n{report}\n"

    print("\nConsolidating individual reviews...")

    orchestrator_config = LocalAgentConfig(
        model=model_name,
        vertex=True,
        project=project_id,
        location=location,
        system_instructions=ORCHESTRATOR_INSTRUCTION,
        skills_paths=["skills/"],
    )

    orchestrator = Agent(orchestrator_config)
    async with orchestrator:
        final_report = await orchestrator.chat(individual_reports)
        report_text = await final_report.text()
        print("\n--- Consolidated Agent Review ---")
        print(report_text)
        print("---------------------------------")

        # Save to local workspace report file to enable GCS artifacts upload in Cloud Build
        try:
            with open("report.md", "w", encoding="utf-8") as f:
                f.write(report_text)
            print("Successfully saved review report to report.md")
        except Exception as e:
            print(f"Warning: Failed to save review report to disk: {e}", file=sys.stderr)


if __name__ == "__main__":
    asyncio.run(main())

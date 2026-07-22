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

"""Unit tests for the agentic pre-build review runner script.

Mocks the google.antigravity Agent connection layers to verify proper parallel execution
and orchestrator consolidation flows.
"""

import asyncio
import os
import sys
from unittest.mock import AsyncMock, MagicMock, patch

# Mock google.antigravity before importing agentic_runner
mock_antigravity = MagicMock()
sys.modules["google.antigravity"] = mock_antigravity

# Bind mock class types for successful imports
mock_antigravity.Agent = MagicMock
mock_antigravity.LocalAgentConfig = MagicMock


# Ensure scripts directory is in path to load agentic_runner
sys.path.append(os.path.join(os.path.dirname(__file__), "../scripts"))
from agentic_runner import main


@patch("asyncio.create_subprocess_exec")
@patch("builtins.open")
@patch("agentic_runner.LocalAgentConfig")
@patch("agentic_runner.Agent")
@patch.dict(
    os.environ,
    {
        "GCP_PROJECT": "test-project",
        "GCP_LOCATION": "us-central1",
        "AGENT_MODEL": "test-model",
        "AGENT_PERSONAS": "swe security",
        "AGENT_PROMPT": "Run review",
    },
)
def test_main_orchestration(mock_agent, mock_config, mock_open, mock_exec):
    """Verifies that main runner triggers parallel reviews and synthesizes reports correctly."""
    # Mocking the Agent connection and chat execution
    mock_process = AsyncMock()
    mock_process.communicate = AsyncMock(return_value=(b"", b""))
    mock_process.returncode = 1
    mock_exec.return_value = mock_process

    mock_agent_instance = MagicMock()
    mock_agent_instance.__aenter__ = AsyncMock(return_value=mock_agent_instance)
    mock_agent_instance.__aexit__ = AsyncMock(return_value=None)

    mock_response = AsyncMock()
    mock_response.text = AsyncMock(return_value="Review output mock")
    mock_agent_instance.chat = AsyncMock(return_value=mock_response)

    mock_agent.return_value = mock_agent_instance
    mock_config.return_value = MagicMock()

    # Run the main function synchronously using asyncio.run
    asyncio.run(main())

    # Verify that 3 Agent configs were created (2 specialists + 1 orchestrator)
    assert mock_config.call_count == 3

    # Verify that 3 Agents were created
    assert mock_agent.call_count == 3

    # Verify Orchestrator synthesis call
    last_chat_call_args = mock_agent_instance.chat.call_args_list[-1][0][0]
    assert "swe" in last_chat_call_args
    assert "security" in last_chat_call_args
    assert "Review output mock" in last_chat_call_args

    # Verify that file write was triggered and sandboxed
    mock_open.assert_called_once_with("report.md", "w", encoding="utf-8")


@patch("os.getuid", return_value=1000)
@patch("os.path.exists", return_value=True)
@patch("asyncio.create_subprocess_exec")
@patch.dict(
    os.environ,
    {
        "SKAFFOLD_PATH": "apps/devcontainers/node-demo",
    },
)
def test_main_custom_agent_discovery_non_root(mock_exec, mock_exists, mock_getuid):
    """Verifies that main runner executes custom script un-sandboxed when running as non-root."""
    mock_process = AsyncMock()
    mock_process.wait = AsyncMock(return_value=0)
    mock_process.returncode = 0
    mock_exec.return_value = mock_process

    try:
        asyncio.run(main())
        assert False, "SystemExit was not raised."
    except SystemExit as e:
        assert e.code == 0

    mock_exists.assert_called_once_with("apps/devcontainers/node-demo/.agentic/review.py")
    mock_exec.assert_called_once_with(
        "python3",
        "apps/devcontainers/node-demo/.agentic/review.py",
    )


@patch("os.getuid", return_value=0)
@patch("os.path.exists", return_value=True)
@patch("asyncio.create_subprocess_exec")
@patch.dict(
    os.environ,
    {
        "SKAFFOLD_PATH": "apps/devcontainers/node-demo",
    },
)
def test_main_custom_agent_discovery_root(mock_exec, mock_exists, mock_getuid):
    """Verifies that main runner executes custom script inside network-gated namespace sandbox when running as root."""
    mock_process = AsyncMock()
    mock_process.wait = AsyncMock(return_value=0)
    mock_process.returncode = 0
    mock_exec.return_value = mock_process

    try:
        asyncio.run(main())
        assert False, "SystemExit was not raised."
    except SystemExit as e:
        assert e.code == 0

    mock_exists.assert_called_once_with("apps/devcontainers/node-demo/.agentic/review.py")
    mock_exec.assert_called_once_with(
        "unshare",
        "-n",
        "runuser",
        "-u",
        "nobody",
        "--",
        "python3",
        "apps/devcontainers/node-demo/.agentic/review.py",
    )

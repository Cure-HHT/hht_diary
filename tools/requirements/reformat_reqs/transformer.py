"""
AI-assisted requirement transformation using Claude Code CLI.

Invokes claude CLI to reformat requirements and assembles the output
into the new format.
"""

import json
import subprocess
import sys
from typing import List, Optional, Tuple

from .hierarchy import RequirementNode
from .prompts import REFORMAT_SYSTEM_PROMPT, JSON_SCHEMA_STR, build_user_prompt


def reformat_requirement(
    node: RequirementNode,
    model: str = "sonnet",
    verbose: bool = False
) -> Tuple[Optional[dict], bool, str]:
    """
    Use Claude CLI to reformat a requirement.

    Args:
        node: RequirementNode with current content
        model: Claude model to use (sonnet, opus, haiku)
        verbose: Print debug information

    Returns:
        Tuple of (parsed_result, success, error_message)
        parsed_result is a dict with 'rationale' and 'assertions' keys
    """
    # Build the prompt
    user_prompt = build_user_prompt(
        req_id=node.req_id,
        title=node.title,
        level=node.level,
        status=node.status,
        implements=node.implements,
        body=node.body,
        rationale=node.rationale
    )

    # Build the claude command
    cmd = [
        'claude',
        '-p',  # Print mode (non-interactive)
        '--output-format', 'json',
        '--json-schema', JSON_SCHEMA_STR,
        '--system-prompt', REFORMAT_SYSTEM_PROMPT,
        '--tools', '',  # Disable all tools
        '--model', model,
        user_prompt
    ]

    if verbose:
        print(f"  Running: claude -p --output-format json ...", file=sys.stderr)

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=120  # 2 minute timeout
        )

        if result.returncode != 0:
            error_msg = result.stderr.strip() if result.stderr else "Unknown error"
            return None, False, f"Claude CLI failed: {error_msg}"

        # Parse the JSON response
        parsed = parse_claude_response(result.stdout)
        if parsed is None:
            return None, False, "Failed to parse Claude response"

        return parsed, True, ""

    except subprocess.TimeoutExpired:
        return None, False, "Claude CLI timed out"
    except FileNotFoundError:
        return None, False, "Claude CLI not found - ensure 'claude' is in PATH"
    except Exception as e:
        return None, False, f"Unexpected error: {e}"


def parse_claude_response(response: str) -> Optional[dict]:
    """
    Parse the JSON response from Claude CLI.

    The response format with --output-format json is a JSON object containing:
    - type: "result"
    - subtype: "success" or "error"
    - structured_output: the actual JSON matching our schema
    - result: text result (may be empty with structured output)

    Args:
        response: Raw stdout from claude CLI

    Returns:
        Parsed dict with 'rationale' and 'assertions', or None on failure
    """
    try:
        data = json.loads(response)

        # Check for error
        if data.get('is_error') or data.get('subtype') == 'error':
            return None

        # The structured output is in 'structured_output' field
        if 'structured_output' in data:
            structured = data['structured_output']
            if isinstance(structured, dict) and 'rationale' in structured and 'assertions' in structured:
                return structured

        # Fallback: Direct result (if schema not used)
        if 'rationale' in data and 'assertions' in data:
            return data

        # Fallback: Wrapped in result field
        if 'result' in data:
            result = data['result']
            if isinstance(result, dict) and 'rationale' in result:
                return result
            # Result might be a JSON string
            if isinstance(result, str) and result.strip():
                try:
                    parsed = json.loads(result)
                    if 'rationale' in parsed:
                        return parsed
                except json.JSONDecodeError:
                    pass

        return None

    except json.JSONDecodeError:
        # Try to extract JSON from the response
        try:
            json_start = response.find('{')
            json_end = response.rfind('}') + 1
            if json_start >= 0 and json_end > json_start:
                parsed = json.loads(response[json_start:json_end])
                if 'structured_output' in parsed:
                    return parsed['structured_output']
                if 'rationale' in parsed and 'assertions' in parsed:
                    return parsed
        except json.JSONDecodeError:
            pass
        return None


def assemble_new_format(
    req_id: str,
    title: str,
    level: str,
    status: str,
    implements: List[str],
    rationale: str,
    assertions: List[str]
) -> str:
    """
    Assemble the new format requirement markdown.

    Args:
        req_id: Requirement ID (e.g., 'REQ-p00046')
        title: Requirement title
        level: Requirement level (PRD, Dev, Ops)
        status: Requirement status
        implements: List of parent requirement IDs
        rationale: Rationale text (from AI)
        assertions: List of assertion strings (from AI)

    Returns:
        Complete requirement markdown in new format
    """
    # Format implements field
    if implements:
        implements_str = ", ".join(implements)
    else:
        implements_str = "-"

    # Build header
    lines = [
        f"# {req_id}: {title}",
        "",
        f"**Level**: {level} | **Status**: {status} | **Implements**: {implements_str}",
        "",
    ]

    # Add rationale section
    lines.append("## Rationale")
    lines.append("")
    lines.append(rationale.strip())
    lines.append("")

    # Add assertions section
    lines.append("## Assertions")
    lines.append("")

    # Label assertions A, B, C, etc.
    for i, assertion in enumerate(assertions):
        label = chr(ord('A') + i)
        # Clean up assertion text
        assertion_text = assertion.strip()
        # Remove any existing label if present
        if len(assertion_text) > 2 and assertion_text[1] == '.' and assertion_text[0].isupper():
            assertion_text = assertion_text[2:].strip()
        lines.append(f"{label}. {assertion_text}")

    lines.append("")

    # Add footer with placeholder hash (will be updated by elspais)
    # Use 8 zeros as placeholder - elspais expects valid hex format
    lines.append(f"*End* *{title}* | **Hash**: 00000000")
    lines.append("")

    return "\n".join(lines)


def validate_reformatted_content(
    original: RequirementNode,
    rationale: str,
    assertions: List[str]
) -> Tuple[bool, List[str]]:
    """
    Validate that reformatted content is well-formed.

    Args:
        original: Original requirement node
        rationale: New rationale text
        assertions: New assertions list

    Returns:
        Tuple of (is_valid, list of warnings)
    """
    warnings = []

    # Check assertions exist
    if not assertions:
        warnings.append("No assertions generated")
        return False, warnings

    # Check each assertion uses SHALL
    for i, assertion in enumerate(assertions):
        label = chr(ord('A') + i)
        if 'SHALL' not in assertion.upper():
            warnings.append(f"Assertion {label} missing SHALL keyword")

    # Check rationale doesn't use SHALL
    if 'SHALL' in rationale.upper():
        warnings.append("Rationale contains SHALL (should be non-normative)")

    # Check assertion count
    if len(assertions) > 26:
        warnings.append(f"Too many assertions ({len(assertions)} > 26)")
        return False, warnings

    # Warning if very few assertions from complex body
    if len(assertions) < 2 and len(original.body) > 500:
        warnings.append("Few assertions from large body - may have missed obligations")

    is_valid = not any("missing SHALL" in w or "No assertions" in w for w in warnings)
    return is_valid, warnings

"""
Prompts and JSON schema for Claude Code CLI integration.

Defines the system prompt and output schema for AI-assisted
requirement reformatting.
"""

import json

# JSON Schema for structured output validation
JSON_SCHEMA = {
    "type": "object",
    "properties": {
        "rationale": {
            "type": "string",
            "description": "Non-normative context explaining why this requirement exists. No SHALL/MUST language."
        },
        "assertions": {
            "type": "array",
            "items": {"type": "string"},
            "description": "List of assertions, each starting with 'The system SHALL...' or similar prescriptive language."
        }
    },
    "required": ["rationale", "assertions"]
}

JSON_SCHEMA_STR = json.dumps(JSON_SCHEMA, separators=(',', ':'))

# System prompt for requirement reformatting
REFORMAT_SYSTEM_PROMPT = """You are a requirements engineering expert specializing in FDA 21 CFR Part 11 compliant clinical trial systems.

Your task is to reformat requirements from an old descriptive format to a new prescriptive assertion-based format.

EXTRACTION RULES:
1. Extract ALL obligations from the old format (body text, bullet points, acceptance criteria)
2. Convert each distinct obligation to a labeled assertion
3. Each assertion MUST use "SHALL" for mandatory obligations or "SHALL NOT" for prohibitions
4. Each assertion MUST be independently testable (decidable as true/false)
5. Assertions MUST be prescriptive, not descriptive
6. Maximum 26 assertions (A-Z) - if more needed, consolidate related obligations
7. Do NOT add obligations that were not in the original
8. Do NOT remove or weaken any obligations from the original
9. Combine related acceptance criteria into single assertions when appropriate

RATIONALE RULES:
1. The rationale provides context for WHY this requirement exists
2. Rationale MUST NOT introduce new obligations
3. Rationale MUST NOT use SHALL/MUST language
4. Rationale can explain regulatory context, design decisions, or relationships to other requirements

LANGUAGE GUIDELINES:
- Use "The system SHALL..." for system behaviors
- Use "The platform SHALL..." for platform-wide requirements
- Use "Data SHALL..." for data-related requirements
- Be specific and unambiguous
- Avoid vague terms like "appropriate", "adequate", "reasonable" unless quantified

OUTPUT FORMAT:
Return a JSON object with:
- "rationale": A paragraph explaining the requirement's purpose (no SHALL language)
- "assertions": An array of strings, each being a complete assertion starting with the subject and SHALL

Example output:
{
  "rationale": "This requirement ensures complete audit trails for regulatory compliance. FDA 21 CFR Part 11 mandates that electronic records maintain tamper-evident histories of all modifications.",
  "assertions": [
    "The system SHALL store all data changes as immutable events.",
    "The system SHALL preserve the complete history of all modifications.",
    "Event records SHALL include timestamp, user ID, and action type.",
    "The system SHALL NOT allow modification or deletion of stored events."
  ]
}"""


def build_user_prompt(
    req_id: str,
    title: str,
    level: str,
    status: str,
    implements: list,
    body: str,
    rationale: str = ""
) -> str:
    """
    Build the user prompt for reformatting a requirement.

    Args:
        req_id: Requirement ID (e.g., 'REQ-p00046')
        title: Requirement title
        level: Requirement level (PRD, Dev, Ops)
        status: Requirement status (Draft, Active, etc.)
        implements: List of parent requirement IDs
        body: Current requirement body text
        rationale: Current rationale text (if any)

    Returns:
        User prompt string
    """
    implements_str = ", ".join(implements) if implements else "-"

    prompt = f"""Reformat the following requirement from old format to new assertion-based format.

REQUIREMENT ID: {req_id}
TITLE: {title}
LEVEL: {level}
STATUS: {status}
IMPLEMENTS: {implements_str}

CURRENT BODY:
{body}
"""

    if rationale and rationale.strip():
        prompt += f"""
CURRENT RATIONALE:
{rationale}
"""

    prompt += """
Extract all obligations and convert them to labeled assertions. Return ONLY the JSON object with "rationale" and "assertions" fields."""

    return prompt

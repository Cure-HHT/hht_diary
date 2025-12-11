#!/usr/bin/env python3
"""
Shared requirement parsing module.

Provides the Requirement dataclass and RequirementParser class used by both
validate_requirements.py and update-REQ-hashes.py.

IMPLEMENTS REQUIREMENTS:
    REQ-d00002: Requirements validation tool
"""

import re
from pathlib import Path
from typing import Dict, List, Optional, Callable
from dataclasses import dataclass, field
from requirement_hash import calculate_requirement_hash, clean_requirement_body


@dataclass
class Requirement:
    """Represents a parsed requirement"""
    id: str
    title: str
    level: str
    implements: List[str]
    status: str
    hash: str  # SHA-256 hash (first 8 chars)
    body: str  # Body text for hash calculation (between status and end marker)
    file_path: Path
    line_number: int
    heading_level: int  # Heading level (1-6)
    rationale: str = ''  # Rationale section extracted from body

    @property
    def level_prefix(self) -> str:
        """Extract level prefix (p, o, d) from ID

        Supports both core IDs (d00001) and sponsor-specific IDs (CAL-d00001)
        """
        match = re.match(r'^(?:[A-Z]{2,4}-)?([pod])(\d{5})$', self.id)
        return match.group(1) if match else ''

    @property
    def number(self) -> int:
        """Extract numeric part of ID

        Supports both core IDs (d00001) and sponsor-specific IDs (CAL-d00001)
        """
        match = re.match(r'^(?:[A-Z]{2,4}-)?([pod])(\d{5})$', self.id)
        return int(match.group(2)) if match else 0

    @property
    def sponsor_prefix(self) -> str:
        """Extract sponsor prefix if present (e.g., 'CAL' from 'CAL-d00001')"""
        match = re.match(r'^([A-Z]{2,4})-[pod]\d{5}$', self.id)
        return match.group(1) if match else ''

    @property
    def base_id(self) -> str:
        """Extract base ID without sponsor prefix (e.g., 'd00001' from 'CAL-d00001')"""
        match = re.match(r'^(?:[A-Z]{2,4}-)?([pod]\d{5})$', self.id)
        return match.group(1) if match else self.id


@dataclass
class ParseError:
    """Represents a parsing error"""
    file_path: Path
    line_number: int
    req_id: str
    message: str

    def __str__(self) -> str:
        return f"{self.file_path.name}:{self.line_number} - REQ-{self.req_id}: {self.message}"


@dataclass
class ParseResult:
    """Result of parsing requirements from a file or directory"""
    requirements: Dict[str, Requirement] = field(default_factory=dict)
    errors: List[ParseError] = field(default_factory=list)


class RequirementParser:
    """Parses requirements from spec files"""

    # Regex patterns for requirement format
    # Supports both core REQs (REQ-d00001) and sponsor-specific REQs (REQ-CAL-d00001)
    REQ_HEADER_PATTERN = re.compile(
        r'^(#{1,6})\s+REQ-(?:([A-Z]{2,4})-)?([pod]\d{5}):\s+(.+)$',
        re.MULTILINE
    )
    STATUS_PATTERN = re.compile(
        r'^\*\*Level\*\*:\s+(PRD|Ops|Dev)\s+\|\s+'
        r'\*\*Implements\*\*:\s+([^\|]+?)\s+\|\s+'
        r'\*\*Status\*\*:\s+(Active|Draft|Deprecated)\s*$',
        re.MULTILINE
    )
    END_MARKER_PATTERN = re.compile(
        r'^\*End\*\s+\*(.+?)\*\s+\|\s+\*\*Hash\*\*:\s+([a-f0-9]{8}|TBD)\s*$',
        re.MULTILINE
    )

    SKIP_FILES = {'INDEX.md', 'README.md', 'requirements-format.md'}

    def __init__(self, spec_dir: Path):
        self.spec_dir = spec_dir

    def parse_all(self, req_filter: Optional[Callable[[str], bool]] = None) -> ParseResult:
        """
        Parse all requirements from spec files.

        Args:
            req_filter: Optional filter function. If provided, only requirements
                       where req_filter(req_id) returns True will be included.

        Returns:
            ParseResult containing requirements dict and any errors
        """
        result = ParseResult()

        for file_path in sorted(self.spec_dir.glob("*.md")):
            if file_path.name in self.SKIP_FILES:
                continue

            content = file_path.read_text(encoding='utf-8')
            file_result = self.parse_file(file_path, content, req_filter)

            result.requirements.update(file_result.requirements)
            result.errors.extend(file_result.errors)

        return result

    def parse_file(
        self,
        file_path: Path,
        content: str,
        req_filter: Optional[Callable[[str], bool]] = None
    ) -> ParseResult:
        """
        Parse all requirements from a single file.

        Args:
            file_path: Path to the file being parsed
            content: File content as string
            req_filter: Optional filter function

        Returns:
            ParseResult containing requirements dict and any errors
        """
        result = ParseResult()

        for header_match in self.REQ_HEADER_PATTERN.finditer(content):
            heading_marks = header_match.group(1)
            heading_level = len(heading_marks)
            sponsor_prefix = header_match.group(2)  # Optional, e.g., "CAL"
            base_id = header_match.group(3)  # e.g., "d00001"
            title = header_match.group(4).strip()
            line_num = content[:header_match.start()].count('\n') + 1

            # Construct full req_id (with or without sponsor prefix)
            req_id = f"{sponsor_prefix}-{base_id}" if sponsor_prefix else base_id

            # Apply filter if provided
            if req_filter and not req_filter(req_id):
                continue

            # Extract content after header
            req_start = header_match.end()
            remaining = content[req_start:]

            # Find status line
            status_match = self.STATUS_PATTERN.search(remaining)
            if not status_match:
                result.errors.append(ParseError(
                    file_path=file_path,
                    line_number=line_num,
                    req_id=req_id,
                    message="Missing or malformed status line"
                ))
                continue

            # Check whitespace-only between header and status
            between_header_status = remaining[:status_match.start()]
            if between_header_status.strip():
                result.errors.append(ParseError(
                    file_path=file_path,
                    line_number=line_num,
                    req_id=req_id,
                    message="Non-whitespace content between header and status line"
                ))

            level = status_match.group(1)
            implements_str = status_match.group(2).strip()
            status = status_match.group(3)

            # Find end marker
            end_marker_match = self.END_MARKER_PATTERN.search(remaining[status_match.end():])
            if not end_marker_match:
                result.errors.append(ParseError(
                    file_path=file_path,
                    line_number=line_num,
                    req_id=req_id,
                    message="Missing end marker with hash"
                ))
                continue

            end_title = end_marker_match.group(1).strip()
            hash_value = end_marker_match.group(2)

            # Validate title matches
            if end_title != title:
                result.errors.append(ParseError(
                    file_path=file_path,
                    line_number=line_num,
                    req_id=req_id,
                    message=f"Title mismatch - header='{title}' vs end='{end_title}' (MANUAL FIX REQUIRED: likely parsing error from before end markers existed)"
                ))

            # Extract body (between status line and end marker)
            body_start = status_match.end()
            body_end = status_match.end() + end_marker_match.start()
            body_text = remaining[body_start:body_end]

            # Clean body using shared function
            full_body = clean_requirement_body(body_text)

            # Extract rationale if present
            rationale = ''
            body = full_body
            rationale_marker = '\n\n**Rationale**:'
            if rationale_marker in full_body:
                parts = full_body.split(rationale_marker, 1)
                body = parts[0]
                rationale = parts[1].strip()

            # Parse implements list
            implements = []
            if implements_str != '-':
                implements = [impl.strip() for impl in implements_str.split(',') if impl.strip()]

            req = Requirement(
                id=req_id,
                title=title,
                level=level,
                implements=implements,
                status=status,
                hash=hash_value,
                body=body,
                file_path=file_path,
                line_number=line_num,
                heading_level=heading_level,
                rationale=rationale
            )

            result.requirements[req_id] = req

        return result


def make_req_filter(specific_req: Optional[str]) -> Optional[Callable[[str], bool]]:
    """
    Create a filter function for a specific requirement ID.

    Args:
        specific_req: Requirement ID to filter for (e.g., 'd00027' or 'CAL-d00027')
                     If None, returns None (no filter)

    Returns:
        Filter function or None
    """
    if not specific_req:
        return None

    # Normalize to lowercase for comparison
    specific_req_lower = specific_req.lower()

    def filter_func(req_id: str) -> bool:
        req_id_lower = req_id.lower()
        # Match full ID
        if req_id_lower == specific_req_lower:
            return True
        # Also match if specific_req is just the base ID
        base_match = re.match(r'^(?:[A-Z]{2,4}-)?([pod]\d{5})$', req_id, re.IGNORECASE)
        if base_match and base_match.group(1).lower() == specific_req_lower:
            return True
        return False

    return filter_func

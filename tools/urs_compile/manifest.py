"""Load and validate tools/urs-section-map.yaml."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any

import yaml


@dataclass(frozen=True)
class Section:
    number: str
    title: str
    files: list[str]


@dataclass(frozen=True)
class Chapter:
    number: int
    title: str
    sections: list[Section]


@dataclass(frozen=True)
class Manifest:
    document: dict[str, Any]
    frontmatter: str | None
    appendices: str | None
    glossary: str | None
    term_index: str | None
    chapters: list[Chapter]

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> "Manifest":
        chapters: list[Chapter] = []
        for ch in d.get("chapters", []):
            if "number" not in ch:
                raise ValueError(f"chapter missing 'number': {ch}")
            sections = [
                Section(
                    number=s["number"],
                    title=s["title"],
                    files=list(s.get("files", [])),
                )
                for s in ch.get("sections", [])
            ]
            chapters.append(Chapter(
                number=int(ch["number"]),
                title=ch["title"],
                sections=sections,
            ))
        return cls(
            document=d.get("document", {}),
            frontmatter=d.get("frontmatter"),
            appendices=d.get("appendices"),
            glossary=d.get("glossary"),
            term_index=d.get("term_index"),
            chapters=chapters,
        )

    @classmethod
    def from_yaml_path(cls, path: Path) -> "Manifest":
        return cls.from_dict(yaml.safe_load(path.read_text()))

#!/usr/bin/env python3
"""
Review Packages Module - Manage groups of REQs under review

Provides data models and storage operations for Review Packages.
Packages are named collections of REQs that are being reviewed together.

IMPLEMENTS REQUIREMENTS:
    REQ-d00092: HTML Report Integration (package management)
"""

import json
import uuid
from datetime import datetime
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, Any, List, Optional


PACKAGES_FILE = "packages.json"


@dataclass
class ReviewPackage:
    """Represents a named collection of REQs under review"""
    packageId: str
    name: str
    description: str
    reqIds: List[str]
    createdBy: str
    createdAt: str
    isDefault: bool = False

    def to_dict(self) -> Dict[str, Any]:
        """Serialize to dictionary"""
        return {
            "packageId": self.packageId,
            "name": self.name,
            "description": self.description,
            "reqIds": self.reqIds.copy(),
            "createdBy": self.createdBy,
            "createdAt": self.createdAt,
            "isDefault": self.isDefault
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'ReviewPackage':
        """Deserialize from dictionary"""
        return cls(
            packageId=data.get("packageId", ""),
            name=data.get("name", ""),
            description=data.get("description", ""),
            reqIds=data.get("reqIds", []).copy(),
            createdBy=data.get("createdBy", ""),
            createdAt=data.get("createdAt", ""),
            isDefault=data.get("isDefault", False)
        )

    @classmethod
    def create_default(cls) -> 'ReviewPackage':
        """Create the default package"""
        return cls(
            packageId="default",
            name="Default",
            description="REQs manually set to Review status",
            reqIds=[],
            createdBy="system",
            createdAt=datetime.utcnow().isoformat() + "Z",
            isDefault=True
        )


@dataclass
class PackagesFile:
    """Container for all packages and active package selection"""
    packages: List[ReviewPackage]
    activePackageId: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        """Serialize to dictionary"""
        return {
            "packages": [p.to_dict() for p in self.packages],
            "activePackageId": self.activePackageId
        }

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'PackagesFile':
        """Deserialize from dictionary"""
        packages = [ReviewPackage.from_dict(p) for p in data.get("packages", [])]
        return cls(
            packages=packages,
            activePackageId=data.get("activePackageId")
        )

    def get_default(self) -> Optional[ReviewPackage]:
        """Get the default package"""
        for pkg in self.packages:
            if pkg.isDefault:
                return pkg
        return None

    def get_active(self) -> Optional[ReviewPackage]:
        """Get the currently active package"""
        if not self.activePackageId:
            return None
        for pkg in self.packages:
            if pkg.packageId == self.activePackageId:
                return pkg
        return None

    def get_by_id(self, package_id: str) -> Optional[ReviewPackage]:
        """Get a package by ID"""
        for pkg in self.packages:
            if pkg.packageId == package_id:
                return pkg
        return None


def _get_packages_path(repo_root: Path) -> Path:
    """Get the path to the packages file"""
    return repo_root / ".reviews" / PACKAGES_FILE


def _ensure_reviews_dir(repo_root: Path) -> Path:
    """Ensure the .reviews directory exists"""
    reviews_dir = repo_root / ".reviews"
    reviews_dir.mkdir(parents=True, exist_ok=True)
    return reviews_dir


def load_packages(repo_root: Path) -> PackagesFile:
    """
    Load packages from storage. Creates default package if file doesn't exist.

    Args:
        repo_root: Path to the repository root

    Returns:
        PackagesFile containing all packages
    """
    packages_path = _get_packages_path(repo_root)

    if packages_path.exists():
        try:
            data = json.loads(packages_path.read_text(encoding='utf-8'))
            return PackagesFile.from_dict(data)
        except (json.JSONDecodeError, IOError):
            pass

    # Create default package file
    default = ReviewPackage.create_default()
    pf = PackagesFile(packages=[default], activePackageId=None)
    save_packages(repo_root, pf)
    return pf


def save_packages(repo_root: Path, packages_file: PackagesFile) -> None:
    """
    Save packages to storage.

    Args:
        repo_root: Path to the repository root
        packages_file: The PackagesFile to save
    """
    _ensure_reviews_dir(repo_root)
    packages_path = _get_packages_path(repo_root)

    # Atomic write
    temp_path = packages_path.with_suffix('.tmp')
    temp_path.write_text(
        json.dumps(packages_file.to_dict(), indent=2),
        encoding='utf-8'
    )
    temp_path.rename(packages_path)


def create_package(
    repo_root: Path,
    name: str,
    description: str,
    user: str
) -> ReviewPackage:
    """
    Create a new review package.

    Args:
        repo_root: Path to the repository root
        name: Name for the package
        description: Description of the package
        user: Username creating the package

    Returns:
        The created ReviewPackage
    """
    pf = load_packages(repo_root)

    pkg = ReviewPackage(
        packageId=str(uuid.uuid4()),
        name=name,
        description=description,
        reqIds=[],
        createdBy=user,
        createdAt=datetime.utcnow().isoformat() + "Z",
        isDefault=False
    )

    pf.packages.append(pkg)
    save_packages(repo_root, pf)

    return pkg


def get_package(repo_root: Path, package_id: str) -> Optional[ReviewPackage]:
    """
    Get a package by ID.

    Args:
        repo_root: Path to the repository root
        package_id: The package ID

    Returns:
        ReviewPackage if found, None otherwise
    """
    pf = load_packages(repo_root)
    return pf.get_by_id(package_id)


def update_package(
    repo_root: Path,
    package_id: str,
    name: Optional[str] = None,
    description: Optional[str] = None
) -> bool:
    """
    Update a package's name or description.

    Args:
        repo_root: Path to the repository root
        package_id: The package ID to update
        name: New name (optional)
        description: New description (optional)

    Returns:
        True if updated, False if package not found
    """
    pf = load_packages(repo_root)
    pkg = pf.get_by_id(package_id)

    if not pkg:
        return False

    if name is not None:
        pkg.name = name
    if description is not None:
        pkg.description = description

    save_packages(repo_root, pf)
    return True


def delete_package(repo_root: Path, package_id: str) -> bool:
    """
    Delete a package.

    Args:
        repo_root: Path to the repository root
        package_id: The package ID to delete

    Returns:
        True if deleted, False if not found or is default
    """
    pf = load_packages(repo_root)
    pkg = pf.get_by_id(package_id)

    if not pkg:
        return False

    # Cannot delete the default package
    if pkg.isDefault:
        return False

    pf.packages = [p for p in pf.packages if p.packageId != package_id]

    # Clear active if we deleted it
    if pf.activePackageId == package_id:
        pf.activePackageId = None

    save_packages(repo_root, pf)
    return True


def add_req_to_package(
    repo_root: Path,
    package_id: str,
    req_id: str
) -> bool:
    """
    Add a REQ to a package.

    Args:
        repo_root: Path to the repository root
        package_id: The package ID
        req_id: The requirement ID to add

    Returns:
        True if added, False if package not found
    """
    pf = load_packages(repo_root)
    pkg = pf.get_by_id(package_id)

    if not pkg:
        return False

    # Idempotent: don't add if already present
    if req_id not in pkg.reqIds:
        pkg.reqIds.append(req_id)
        save_packages(repo_root, pf)

    return True


def remove_req_from_package(
    repo_root: Path,
    package_id: str,
    req_id: str
) -> bool:
    """
    Remove a REQ from a package.

    Args:
        repo_root: Path to the repository root
        package_id: The package ID
        req_id: The requirement ID to remove

    Returns:
        True if removed, False if package not found
    """
    pf = load_packages(repo_root)
    pkg = pf.get_by_id(package_id)

    if not pkg:
        return False

    if req_id in pkg.reqIds:
        pkg.reqIds.remove(req_id)
        save_packages(repo_root, pf)

    return True


def get_active_package(repo_root: Path) -> Optional[ReviewPackage]:
    """
    Get the currently active package.

    Args:
        repo_root: Path to the repository root

    Returns:
        The active ReviewPackage, or None if no active package
    """
    pf = load_packages(repo_root)
    return pf.get_active()


def set_active_package(repo_root: Path, package_id: Optional[str]) -> bool:
    """
    Set the active package.

    Args:
        repo_root: Path to the repository root
        package_id: The package ID to make active, or None to clear

    Returns:
        True if set, False if package not found (when package_id is not None)
    """
    pf = load_packages(repo_root)

    if package_id is None:
        pf.activePackageId = None
        save_packages(repo_root, pf)
        return True

    pkg = pf.get_by_id(package_id)
    if not pkg:
        return False

    pf.activePackageId = package_id
    save_packages(repo_root, pf)
    return True


def get_default_package(repo_root: Path) -> Optional[ReviewPackage]:
    """
    Get the default package.

    Args:
        repo_root: Path to the repository root

    Returns:
        The default ReviewPackage
    """
    pf = load_packages(repo_root)
    return pf.get_default()


def get_package_for_req(repo_root: Path, req_id: str) -> Optional[ReviewPackage]:
    """
    Find which package contains a REQ.

    Args:
        repo_root: Path to the repository root
        req_id: The requirement ID to search for

    Returns:
        The ReviewPackage containing the REQ, or None if not in any package
    """
    pf = load_packages(repo_root)

    for pkg in pf.packages:
        if req_id in pkg.reqIds:
            return pkg

    return None


if __name__ == "__main__":
    # Simple CLI for testing
    import sys

    if len(sys.argv) < 2:
        print("Usage: python review_packages.py <repo_root> [command] [args]")
        print("Commands: list, create <name>, add <pkg_id> <req_id>, active [pkg_id]")
        sys.exit(1)

    repo_root = Path(sys.argv[1])
    cmd = sys.argv[2] if len(sys.argv) > 2 else "list"

    if cmd == "list":
        pf = load_packages(repo_root)
        for pkg in pf.packages:
            active = " (active)" if pkg.packageId == pf.activePackageId else ""
            default = " [default]" if pkg.isDefault else ""
            print(f"{pkg.packageId}: {pkg.name}{default}{active} - {len(pkg.reqIds)} REQs")
    elif cmd == "create" and len(sys.argv) > 3:
        pkg = create_package(repo_root, sys.argv[3], "", "cli_user")
        print(f"Created package: {pkg.packageId}")
    elif cmd == "add" and len(sys.argv) > 4:
        success = add_req_to_package(repo_root, sys.argv[3], sys.argv[4])
        print(f"Added: {success}")
    elif cmd == "active":
        if len(sys.argv) > 3:
            set_active_package(repo_root, sys.argv[3])
            print(f"Set active: {sys.argv[3]}")
        else:
            active = get_active_package(repo_root)
            print(f"Active: {active.name if active else 'None'}")

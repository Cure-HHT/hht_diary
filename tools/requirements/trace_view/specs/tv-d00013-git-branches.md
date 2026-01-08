# REQ-tv-d00013: Git Branch Management

**Level**: Dev | **Status**: Draft | **Implements**: REQ-tv-p00002

## Assertions

A. Review branches SHALL follow the naming convention `reviews/{package_id}/{username}`.

B. `get_review_branch_name(package_id, user)` SHALL return the formatted branch name.

C. `parse_review_branch_name(branch_name)` SHALL extract and return a tuple of `(package_id, username)` from a valid branch name.

D. `is_review_branch(branch_name)` SHALL return True only for branches matching the `reviews/{package}/{user}` pattern.

E. `list_package_branches(repo_root, package_id)` SHALL return all branch names for a given package across all users.

F. `get_current_package_context(repo_root)` SHALL return `(package_id, username)` when on a review branch, or `(None, None)` otherwise.

G. `commit_and_push_reviews(repo_root, message)` SHALL commit all changes in `.reviews/` and push to the remote tracking branch.

H. Branch operations SHALL detect and report conflicts without causing data loss.

I. `fetch_package_branches(repo_root, package_id)` SHALL fetch all remote branches for a package to enable merge operations.

## Rationale

The branch-per-user-per-package model enables isolated work with eventual consistency. Each reviewer can work offline on their own branch, and data is consolidated when viewing the package by merging from all contributor branches.

The naming convention makes it easy to discover all contributors to a package review and to filter branches by package.

*End* *Git Branch Management* | **Hash**: 00000000

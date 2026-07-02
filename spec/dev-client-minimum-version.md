# DIARY-DEV-client-minimum-version: Client Minimum Version and Force Upgrade

**Level**: DEV | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-mobile-diary-application

## Overview

The mechanism by which the *Mobile Application* keeps its installed base current enough to remain compliant and compatible: a defined minimum required version, a runtime check that informs *Users* of available updates, and a hard gate that forces an upgrade when the installed version falls below the minimum.

## Assertions

A. The System SHALL define a minimum required version for the *Mobile Application*.

B. The *Mobile Application* SHALL perform a runtime version check to determine whether an update is available and SHALL inform the *User* when one is.

C. The *Mobile Application* SHALL perform the version check automatically at least once daily during use.

D. When the installed version is lower than the minimum required version, the *Mobile Application* SHALL require the *User* to upgrade before continuing to use the application.

## Rationale

A regulated *Diary* whose data contract, security posture, or event schema has moved on cannot safely accept entries from an outdated client, so the platform needs both a soft nudge (an available-update notice) and a hard floor (a force-upgrade gate) below which the client will not operate. A daily automatic check keeps the installed base current without depending on the *User* to look, and a single declared minimum version gives operations one lever to retire a client that is no longer acceptable.

*End* *Client Minimum Version and Force Upgrade* | **Hash**: 91c58030

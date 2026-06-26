# DIARY-BASE-mobile-notifications: Mobile Notifications and Reminders

**Level**: BASE | **Status**: Draft | **Implements**: -
**Refines**: DIARY-BASE-mobile-diary-application

## Overview

The on-device notification and reminder surface of the mobile *Diary* application. It prompts the *Participant* about time-sensitive *Diary* obligations — incomplete records, assigned questionnaires, missed days, ongoing events — without exposing clinical content outside the application. The individual notification behaviors refine this requirement.

## Assertions

A. The *Mobile Application* SHALL surface notifications and reminders to the *Participant* for time-sensitive *Diary* obligations.

B. A notification SHALL NOT disclose clinical content outside the application's authenticated surface.

## Rationale

Adherence in an eDiary depends on timely prompting, so notifications are a first-class part of the *Participant* experience rather than an afterthought. Withholding clinical content from the notification itself keeps protected data inside the authenticated application even when a device surfaces a notification on a lock screen or to another viewer.

*End* *Mobile Notifications and Reminders* | **Hash**: ad5a0d36

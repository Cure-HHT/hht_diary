# DIARY-OPS-fcm-project-routing: FCM Project Routing

**Level**: OPS | **Status**: Draft
**Refines**: DIARY-PRD-ancillary-platform-services

## Assertions

A. The FCM sender project for a deployment SHALL be resolved from a declarative routing manifest keyed by *Sponsor* and environment, not from a compiled-in constant.

B. The cross-project IAM grant authorizing a deployment's sending identity to send FCM from its resolved project SHALL be declared in infrastructure-as-code.

C. The Firebase Cloud Messaging API SHALL be enabled on each resolved FCM project via infrastructure-as-code.

D. The routing manifest SHALL define both a non-production and a production target for every *Sponsor*.

*End* *FCM Project Routing* | **Hash**: b650c1cb

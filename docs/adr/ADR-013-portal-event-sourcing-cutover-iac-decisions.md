# ADR-013: Portal `event_sourcing_datastore` Cutover — Database Administration & IaC Boundary Decisions

**Status:** Obsolete.

The portal runs as `portal_server_evs` over the `event_sourcing` library; its `PostgresBackend`
owns the event-store schema at runtime, and infrastructure-as-code is Terraform.

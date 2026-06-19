# Cloud Run Deployment

Server builds and Cloud Run deployment are owned by the sponsor repos, not this core repo.

- Reusable Terraform modules + deploy workflow templates: **`hht_sponsor_iac`**.
- Per-sponsor deployment (image build, Cloud Run, content overlay): each
  **`hht_diary_<sponsor>`** repo — e.g. `hht_diary_callisto/deployment/README.md`.
- Identity / Workload Identity Federation / admin-project Terraform: **`hht_admin`**.

This core repo builds only the shared `sponsor-ci` base image
(`.github/workflows/build-sponsor-ci.yml`); sponsor repos pull it, overlay their content,
compile their servers (the `portal-final` image), and deploy the `portal-service` Cloud Run
service.

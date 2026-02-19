# modules/cicd-service-account/variables.tf

variable "sponsor" {
  description = "Sponsor name"
  type        = string
}

variable "host_project_id" {
  description = "Project ID where the service account is created (usually dev project)"
  type        = string
}

variable "host_project_number" {
  description = "Project number where the service account is created (usually dev project)"
  type        = string
}

variable "target_project_ids" {
  description = "List of project IDs where CI/CD roles should be granted"
  type        = list(string)
}

variable "dev_qa_project_ids" {
  description = "Dev and QA project IDs (for Anspar admin owner access)"
  type        = list(string)
  default     = []
}

variable "uat_prod_project_ids" {
  description = "UAT and Prod project IDs (for Anspar admin viewer access)"
  type        = list(string)
  default     = []
}

variable "enable_workload_identity" {
  description = "Enable Workload Identity Federation for GitHub Actions"
  type        = bool
  default     = true
}

variable "github_org" {
  description = "GitHub organization name for Workload Identity"
  type        = string
  default     = "Cure-HHT"
}

variable "github_repo" {
  description = "GitHub repository name for Workload Identity"
  type        = string
  default     = "hht_diary"
}

variable "anspar_admin_group" {
  description = "Google group email for Anspar administrators (optional)"
  type        = string
  default     = ""
}

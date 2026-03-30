# Copyright 2024-2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# go/keep-sorted start block=yes newline_separated=yes
output "cloud_build_trigger_github_connection_needed" {
  description = "Instructions to connect GitHub repository if using GitHub source."
  value       = length(local.all_apps) > 0 ? module.cicd_pipelines[0].cloud_build_trigger_github_connection_needed : null
}

output "cloud_build_trigger_ids" {
  description = "The full resource IDs of the Cloud Build triggers."
  value       = length(local.all_apps) > 0 ? module.cicd_pipelines[0].cloud_build_trigger_id : {}
}

output "cloud_build_trigger_trigger_ids" {
  description = "The unique short IDs of the Cloud Build triggers."
  value       = length(local.all_apps) > 0 ? module.cicd_pipelines[0].cloud_build_trigger_trigger_id : {}
}

output "cws_clusters" {
  description = "A map of Cloud Workstation clusters, with their IDs and other attributes."
  value       = module.workstations.cws_clusters
}

output "secure_source_manager_instance_git_http" {
  description = "The Git HTTP URI of the created Secure Source Manager instance."
  value       = length(local.all_apps) > 0 ? module.cicd_pipelines[0].secure_source_manager_instance_git_http : null
}

output "secure_source_manager_instance_git_ssh" {
  description = "The Git SSH URI of the created Secure Source Manager instance."
  value       = length(local.all_apps) > 0 ? module.cicd_pipelines[0].secure_source_manager_instance_git_ssh : null
}

output "secure_source_manager_instance_html" {
  description = "The HTML hostname of the created Secure Source Manager instance."
  value       = length(local.all_apps) > 0 ? module.cicd_pipelines[0].secure_source_manager_instance_html : null
}

output "secure_source_manager_repository_git_html" {
  description = "The Git HTML URI of the created Secure Source Manager repository."
  value       = length(local.all_apps) > 0 ? module.cicd_pipelines[0].secure_source_manager_repository_git_html : null
}

output "secure_source_manager_repository_git_https" {
  description = "The Git HTTP URI of the created Secure Source Manager repository."
  value       = length(local.all_apps) > 0 ? module.cicd_pipelines[0].secure_source_manager_repository_git_https : null
}
# go/keep-sorted end

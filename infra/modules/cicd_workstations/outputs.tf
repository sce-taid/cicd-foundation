# Copyright 2023-2025 Google LLC
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
output "cws_clusters" {
  description = "A map of Cloud Workstation clusters, with their IDs and other attributes."
  value = {
    for key, cluster in google_workstations_workstation_cluster.cluster :
    key => {
      id                     = cluster.id
      network                = cluster.network
      subnetwork             = cluster.subnetwork
      location               = cluster.location
      private_cluster_config = cluster.private_cluster_config
    }
  }
}

output "cws_configs" {
  description = "A map of Cloud Workstation configurations, with their IDs and other attributes."
  value = {
    for key, config in google_workstations_workstation_config.config :
    key => {
      id                     = config.id
      workstation_cluster_id = config.workstation_cluster_id
      location               = config.location
    }
  }
}

output "cws_instances" {
  description = "A map of Cloud Workstation instances, with their IDs and other attributes."
  value = {
    for key, workstation in google_workstations_workstation.workstation :
    key => {
      id                     = workstation.id
      workstation_config_id  = workstation.workstation_config_id
      workstation_cluster_id = workstation.workstation_cluster_id
      location               = workstation.location
      workstation_id         = workstation.workstation_id
    }
  }
}

output "cws_service_account_email" {
  description = "The email address of the Cloud Workstations Service Account."
  value       = module.cws_service_account.email
}
# go/keep-sorted end

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

locals {
  configs_with_creators = {
    for key, config in var.cws_configs : key => config
    if length(coalesce(config.creators, [])) > 0
  }
  workstation_map = {
    for item in flatten([
      for config_key, config_value in var.cws_configs : [
        for instance in config_value.instances : {
          resource_key = "${config_key}-${instance.name}"
          ws_name      = instance.name
          display_name = coalesce(config_value.display_name, instance.name)
          config_key   = config_key
          users        = instance.users
        }
      ]
    ]) : item.resource_key => item
  }
  # Map each config key to its corresponding Cloud Workstation Cluster resource.
  config_to_cluster_map = {
    for config_key, config_value in var.cws_configs : config_key =>
    google_workstations_workstation_cluster.cluster[config_value.cws_cluster]
  }
}

# Cloud Workstation Clusters
resource "google_workstations_workstation_cluster" "cluster" {
  for_each = var.cws_clusters
  provider = google-beta

  project                = data.google_project.project.project_id
  workstation_cluster_id = each.key
  network                = "projects/${data.google_project.project.project_id}/global/networks/${each.value.network}"
  subnetwork             = "projects/${data.google_project.project.project_id}/regions/${each.value.region}/subnetworks/${each.value.subnetwork}"
  location               = each.value.region
  labels                 = local.common_labels

  lifecycle {
    ignore_changes = [
      labels,
    ]
  }
}

# Cloud Workstation Configs
resource "google_workstations_workstation_config" "config" {
  for_each = var.cws_configs
  provider = google-beta

  project                = local.config_to_cluster_map[each.key].project
  workstation_config_id  = each.key
  workstation_cluster_id = local.config_to_cluster_map[each.key].workstation_cluster_id
  location               = local.config_to_cluster_map[each.key].location
  display_name           = each.value.display_name
  idle_timeout           = "${each.value.idle_timeout_seconds}s"
  dynamic "container" {
    for_each = each.value.image != null ? [1] : []

    content {
      image = each.value.image
    }
  }
  host {
    gce_instance {
      machine_type                 = each.value.machine_type
      boot_disk_size_gb            = each.value.boot_disk_size_gb
      service_account              = module.cws_service_account.email
      service_account_scopes       = var.cws_scopes
      disable_public_ip_addresses  = each.value.disable_public_ip_addresses
      pool_size                    = each.value.pool_size
      enable_nested_virtualization = each.value.enable_nested_virtualization
      dynamic "accelerators" {
        for_each = coalesce(each.value.accelerators, [])

        content {
          type  = accelerators.value.type
          count = accelerators.value.count
        }
      }
      dynamic "shielded_instance_config" {
        for_each = each.value.shielded_instance_config == null ? [] : [each.value.shielded_instance_config]

        content {
          enable_secure_boot          = shielded_instance_config.value.enable_secure_boot
          enable_vtpm                 = shielded_instance_config.value.enable_vtpm
          enable_integrity_monitoring = shielded_instance_config.value.enable_integrity_monitoring
        }
      }
      dynamic "boost_configs" {
        for_each = coalesce(each.value.boost_configs, [])
        content {
          id                           = boost_configs.value.id
          machine_type                 = boost_configs.value.machine_type
          boot_disk_size_gb            = boost_configs.value.boot_disk_size_gb
          enable_nested_virtualization = boost_configs.value.enable_nested_virtualization
          pool_size                    = boost_configs.value.pool_size
          dynamic "accelerators" {
            for_each = coalesce(boost_configs.value.accelerators, [])
            content {
              type  = accelerators.value.type
              count = accelerators.value.count
            }
          }
        }
      }
    }
  }
  persistent_directories {
    mount_path = "/home"
    gce_pd {
      source_snapshot = each.value.persistent_disk_source_snapshot
      size_gb         = each.value.persistent_disk_size_gb
      fs_type         = each.value.persistent_disk_fs_type
      disk_type       = each.value.persistent_disk_type
      reclaim_policy  = each.value.persistent_disk_reclaim_policy
    }
  }
  labels = local.common_labels

  lifecycle {
    ignore_changes = [
      labels,
    ]
  }
}

# IAM policy for granting the ability to create Cloud Workstation instances
# out of the Cloud Workstation Config.
# cf. https://cloud.google.com/iam/docs/roles-permissions/workstations#workstations.workstationCreator
data "google_iam_policy" "creators" {
  for_each = local.configs_with_creators

  binding {
    role    = "roles/workstations.workstationCreator"
    members = [for user in each.value.creators : "user:${user}"]
  }
}

# Resource to apply the IAM policy to each Cloud Workstation Config.
resource "google_workstations_workstation_config_iam_policy" "creators" {
  for_each = local.configs_with_creators
  provider = google-beta

  project                = google_workstations_workstation_config.config[each.key].project
  location               = google_workstations_workstation_config.config[each.key].location
  workstation_cluster_id = google_workstations_workstation_config.config[each.key].workstation_cluster_id
  workstation_config_id  = google_workstations_workstation_config.config[each.key].workstation_config_id
  policy_data            = data.google_iam_policy.creators[each.key].policy_data

  depends_on = [google_workstations_workstation_config.config]
}

# Cloud Workstation instances
resource "google_workstations_workstation" "workstation" {
  for_each = local.workstation_map
  provider = google-beta

  project                = local.config_to_cluster_map[each.value.config_key].project
  workstation_cluster_id = local.config_to_cluster_map[each.value.config_key].workstation_cluster_id
  location               = local.config_to_cluster_map[each.value.config_key].location
  workstation_config_id  = google_workstations_workstation_config.config[each.value.config_key].workstation_config_id
  workstation_id         = each.value.ws_name
  display_name           = each.value.display_name
  labels                 = local.common_labels

  lifecycle {
    ignore_changes = [
      labels,
    ]
  }
}

# IAM policy for granting the ability to use Cloud Workstation instances.
# cf. https://cloud.google.com/iam/docs/roles-permissions/workstations#workstations.user
data "google_iam_policy" "users" {
  for_each = local.workstation_map

  binding {
    role    = "roles/workstations.user"
    members = [for user in each.value.users : "user:${user}"]
  }
}

# Resource to apply the IAM policy to each Cloud Workstation instance.
resource "google_workstations_workstation_iam_policy" "iam_policies" {
  for_each = local.workstation_map
  provider = google-beta

  project                = google_workstations_workstation.workstation[each.key].project
  location               = google_workstations_workstation.workstation[each.key].location
  workstation_cluster_id = google_workstations_workstation.workstation[each.key].workstation_cluster_id
  workstation_config_id  = google_workstations_workstation.workstation[each.key].workstation_config_id
  workstation_id         = google_workstations_workstation.workstation[each.key].workstation_id
  policy_data            = data.google_iam_policy.users[each.key].policy_data
}

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

module "docker_artifact_registry" {
  count = var.artifact_registry_id == null ? 1 : 0

  source = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/artifact-registry?ref=v45.0.0"

  name       = "${local.prefix}${var.artifact_registry_name}"
  project_id = local.artifact_registry_project_id
  location   = var.artifact_registry_region
  format = {
    docker = {
      standard = {}
    }
  }
  labels = local.common_labels
}

data "google_artifact_registry_repository" "container_repository" {
  project       = local.artifact_registry_project_id
  location      = var.artifact_registry_region
  repository_id = var.artifact_registry_id == null ? "${local.prefix}${var.artifact_registry_name}" : var.artifact_registry_id
  depends_on = [
    module.docker_artifact_registry
  ]
}

resource "google_artifact_registry_repository_iam_member" "reader" {
  for_each = toset(concat([
    module.service_account_cloud_build.iam_email
    ],
    length(local.scheduled_apps) > 0 ? [
      module.cws_image_build_runner_service_account[0].iam_email
    ] : [],
    var.artifact_registry_readers
  ))

  project    = local.artifact_registry_project_id
  location   = var.artifact_registry_region
  repository = data.google_artifact_registry_repository.container_repository.id
  role       = "roles/artifactregistry.reader"
  member     = each.key
}

resource "google_artifact_registry_repository_iam_member" "writer" {
  project    = local.artifact_registry_project_id
  location   = var.artifact_registry_region
  repository = data.google_artifact_registry_repository.container_repository.id
  role       = "roles/artifactregistry.repoAdmin"
  member     = module.service_account_cloud_build.iam_email
}

# Terraform Module for supporting Cloud Workstations with custom images (`cicd_workstations`)

This module provisions
[Google Cloud Workstations](https://cloud.google.com/workstations/docs/overview),
providing managed, secure, and customizable development environments on Google
Cloud.

It allows you to define and manage:

*   **Workstation Clusters**: The top-level resource that defines the region and
    network for your workstations.
*   **Workstation Configurations**: Templates that define workstation settings
    like machine type, disk size, pool size, idle timeouts, and crucially, the
    container image to use for the development environment. This allows using
    custom images built via CI/CD pipelines (e.g., using the `cicd_pipelines`
    module).
*   **Workstation Instances**: Specific workstation instances based on a
    configuration, with assigned users.
*   **IAM**: Permissions for users to create or use workstations.

## Features

*   **Managed Development Environments**: Sets up Cloud Workstations clusters,
    configurations, and individual workstation instances.
*   **Custom Images**: Easily specify custom container images for workstation
    configurations, allowing standardized and pre-configured development
    environments.
*   **Networking**: Configures workstation clusters within your VPC network and
    subnets.
*   **Persistent Storage**: Supports persistent disks for retaining user data
    and IDE state across sessions.
*   **IAM Integration**: Manages IAM policies to grant specific users or groups
    permissions to create or access workstations.
*   **Fine-Grained Configuration**: Control machine types, disk sizes, idle
    timeouts, pool sizes, and more.

## Usage

Below is a basic usage example. It defines one cluster in `us-central1` and one
workstation configuration that uses a custom image and grants access to a
specific user.

```terraform
module "cicd_workstations" {
  source = "github.com/GoogleCloudPlatform/cicd-foundation//infra/modules/cicd_workstations?ref=v5.0.0"

  project_id = "your-gcp-project-id"

  cws_clusters = {
    "us-central1-cluster" = {
      region     = "us-central1"
      network    = "projects/your-gcp-project-id/global/networks/default"
      subnetwork = "projects/your-gcp-project-id/regions/us-central1/subnetworks/default"
    }
  }

  cws_configs = {
    "ide-1" = {
      cws_cluster                    = "us-central1-cluster"
      image                          = "us-central1-docker.pkg.dev/your-gcp-project-id/cicd-foundation/ide-1:latest"
      machine_type                   = "e2-standard-4"
      boot_disk_size_gb              = 50
      disable_public_ip_addresses    = true
      enable_nested_virtualization   = false
      idle_timeout_seconds           = 7200
      pool_size                      = 1
      persistent_disk_type           = "pd-standard"
      persistent_disk_size_gb        = 200
      persistent_disk_reclaim_policy = "RETAIN"
      creators = [
        "group:your-dev-group@example.com",
      ]
      instances = [
        {
          name  = "developer-1-instance"
          users = ["user:developer-1@example.com"]
        }
      ]
    }
  }
}
```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cws_clusters"></a> [cws\_clusters](#input\_cws\_clusters) | A map of Cloud Workstation clusters to create. The key of the map is used as the unique ID for the cluster. | <pre>map(object({<br/>    network    = string<br/>    region     = string<br/>    subnetwork = string<br/>    vpc_project = optional(string)<br/>    domain_config = optional(object({<br/>      domain = string<br/>    }))<br/>    private_cluster_config = optional(object({<br/>      enable_private_endpoint = optional(bool, false)<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_cws_configs"></a> [cws\_configs](#input\_cws\_configs) | A map of Cloud Workstation configurations. | <pre>map(object({<br/>    # go/keep-sorted start<br/>    accelerators = optional(list(object({<br/>      type  = string<br/>      count = number<br/>    })), [])<br/>    boost_configs = optional(list(object({<br/>      id = string<br/>      accelerators = optional(list(object({<br/>        type  = string<br/>        count = number<br/>      })), [])<br/>      boot_disk_size_gb            = optional(number)<br/>      enable_nested_virtualization = optional(bool)<br/>      machine_type                 = optional(string)<br/>      pool_size                    = optional(number)<br/>    })), [])<br/>    boot_disk_size_gb            = number<br/>    creators                     = optional(list(string))<br/>    cws_cluster                  = string<br/>    disable_public_ip_addresses  = bool<br/>    display_name                 = optional(string)<br/>    enable_nested_virtualization = bool<br/>    idle_timeout_seconds         = number<br/>    image                        = optional(string)<br/>    instances = optional(list(object({<br/>      name         = string<br/>      display_name = optional(string)<br/>      users        = list(string)<br/>    })))<br/>    machine_type                    = string<br/>    persistent_disk_fs_type         = optional(string)<br/>    persistent_disk_reclaim_policy  = optional(string, "RETAIN")<br/>    persistent_disk_size_gb         = optional(number)<br/>    persistent_disk_source_snapshot = optional(string)<br/>    persistent_disk_type            = string<br/>    pool_size                       = number<br/>    shielded_instance_config = optional(object({<br/>      enable_secure_boot          = optional(bool, true)<br/>      enable_vtpm                 = optional(bool, true)<br/>      enable_integrity_monitoring = optional(bool, true)<br/>    }), null)<br/>    # go/keep-sorted end<br/>  }))</pre> | `{}` | no |
| <a name="input_cws_scopes"></a> [cws\_scopes](#input\_cws\_scopes) | The scope of the Cloud Workstations Service Account | `list(string)` | <pre>[<br/>  "https://www.googleapis.com/auth/cloud-platform"<br/>]</pre> | no |
| <a name="input_cws_service_account_name"></a> [cws\_service\_account\_name](#input\_cws\_service\_account\_name) | Name of the Cloud Workstations Service Account | `string` | `"workstations"` | no |
| <a name="input_enable_apis"></a> [enable\_apis](#input\_enable\_apis) | Whether to enable the required APIs for the module. | `bool` | `true` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Common labels to be applied to resources. | `map(string)` | `{}` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project-ID that references existing project for deploying Cloud Workstations. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cws_clusters"></a> [cws\_clusters](#output\_cws\_clusters) | A map of Cloud Workstation clusters, with their IDs and other attributes. |
| <a name="output_cws_configs"></a> [cws\_configs](#output\_cws\_configs) | A map of Cloud Workstation configurations, with their IDs and other attributes. |
| <a name="output_cws_instances"></a> [cws\_instances](#output\_cws\_instances) | A map of Cloud Workstation instances, with their IDs and other attributes. |
| <a name="output_cws_service_account_email"></a> [cws\_service\_account\_email](#output\_cws\_service\_account\_email) | The email address of the Cloud Workstations Service Account. |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

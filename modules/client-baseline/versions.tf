# Provider requirements for the client-baseline module.
# Versions are intentionally not pinned here; each client folder gets a
# .terraform.lock.hcl on first `terraform init`, which pins versions per client.

terraform {
  required_version = ">= 1.13.0"

  required_providers {
    jamfpro = {
      source = "deploymenttheory/jamfpro"
    }
    jamfprotect = {
      source = "Jamf-Concepts/jamfprotect"
    }
    # jamfplatform intentionally NOT required here — Platform features live
    # in modules/client-platform (optional per client via platform.tf).
  }
}

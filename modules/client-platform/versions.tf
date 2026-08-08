# Provider requirements for the client-platform module (Jamf Platform API:
# Blueprints, passcode policy, CIS benchmark).
#
# WHY THIS IS A SEPARATE MODULE (VERIFIED live 2026-08-01): the jamfplatform
# provider authenticates during `terraform plan` even when every Platform
# resource is disabled (count = 0). Clients without Platform API access must
# not load this module at all — that is controlled by the presence of
# clients/<Client>/platform.tf (rename platform.tf.off to enable).

terraform {
  required_version = ">= 1.13.0"

  required_providers {
    jamfplatform = {
      source = "Jamf-Concepts/jamfplatform"
    }
  }
}

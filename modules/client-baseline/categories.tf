# Standard Jamf Pro categories used by every baseline deployment.

resource "jamfpro_category" "security" {
  name     = "Security"
  priority = 1
}

resource "jamfpro_category" "remote_support" {
  name     = "Remote Support"
  priority = 5
}

resource "jamfpro_category" "identity" {
  name     = "Identity & Login"
  priority = 5
}

# clients/

One folder per client. Each folder holds that client's settings
(`terraform.tfvars`), Terraform state (`terraform.tfstate`), and provider
lock file — together they ARE the record of that client's deployment.
Keep this whole repo in OneDrive so they're backed up.

- `_TEMPLATE/` — never run Terraform here. It's the master copy that
  `../new-client.sh` clones for each new client.
- Don't copy `terraform.tfstate` between client folders.
- See ../README.md for the full onboarding procedure.

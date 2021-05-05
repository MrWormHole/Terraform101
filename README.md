terraform --version (this matters for your main.tf file provider definitions)

terraform init (just like git init, starts terraform history tree)

terraform plan (just like git diff origin/master, shows diffs in the infra)

terraform apply --auto-approve (applies the infra without prompting)

terraform destroy (desroys the whole infra)

terraform validate (syntax check for tf files)

terraform state list (this will show your named resources)

terraform state show <provider>.<resource_type> (this will show more details of your named resource)
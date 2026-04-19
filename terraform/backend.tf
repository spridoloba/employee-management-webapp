# Remote state backend.
#
# Local state is the default during early dev. To switch to remote state on
# Azure, create the backing storage account ONCE (e.g. via scripts below)
# and uncomment the backend "azurerm" block.
#
# One-time bootstrap (run once, not via Terraform so state has somewhere to live):
#   az group create -n tfstate-rg -l eastus
#   az storage account create -n tfstateemapp<unique> -g tfstate-rg -l eastus \
#       --sku Standard_LRS --encryption-services blob
#   az storage container create -n tfstate \
#       --account-name tfstateemapp<unique>
#
# Then migrate:
#   terraform init -migrate-state

terraform {
  # backend "azurerm" {
  #   resource_group_name  = "tfstate-rg"
  #   storage_account_name = "tfstateemappXXXXXX"   # must be globally unique
  #   container_name       = "tfstate"
  #   key                  = "prod.emapp.tfstate"
  # }
}

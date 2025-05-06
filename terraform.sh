# include guard
if [[ -n "$_TERRAFORM_SH_INCLUDED" ]]; then
  return
fi
_TERRAFORM_SH_INCLUDED=1

# includes
# ########

source sanity.sh
source logging.sh
source files.sh
source azure.sh

# functions
# #########

function terraform_backend_create() {

  local FILE_variables_backend=$1

  log_title "Terraform backend create"

  ensure_file ${FILE_variables_backend}

  # backend resource group
  local rg=$(value_from ${FILE_variables_backend} resource_group_name)
  local location=$(value_from ${FILE_variables_backend} location)
  azure_create_rg "${rg}" "${location}"

  # backend storage account
  local sa_name=$(value_from ${FILE_variables_backend} storage_account_name)
  azure_create_sa "${rg}" "${location}" "${sa_name}" "Standard_LRS" "Cool" "true"

  # backend storage account container
  local sa_container_name=$(value_from ${FILE_variables_backend} container_name)
  azure_create_sa_container "${sa_name}" "${sa_container_name}"

  log_info "Terraform backend created successfully"
}

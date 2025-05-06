# include guard
if [[ -n "$_AZURE_SH_INCLUDED" ]]; then
  return
fi
_AZURE_SH_INCLUDED=1

# includes
# ########

source sanity.sh
source logging.sh

# sanity
# ######

ensure_command az
ensure_command jq

# functions
# #########

function azure_create_rg() {

    log_info "Create resource group..."

    local rg=${1}
    local location=${2}

    { \
        [[ ${rg} != "" ]] && \
        [[ ${location} != "" ]] \
    } || { log_error "Function argument missing"; }

    local rg_found=$(az group list |jq -r ".[] | select(.name == \"${rg}\") | .id")

    # early exit if resource already exists...
    [[ "${rg_found}" != "" ]] && \
        { log_info "Group '${rg}' already created"; return; }

    # ...create resource otherwise
    run az group create \
        --name "${rg}" \
        --location "${location}"

    log_info "Group '${rg}' created successfully"
}

function azure_create_sa() {

    log_info "Create storage account..."

    local rg=${1}
    local location=${2}
    local sa_name=${3}
    local sa_sku=${4}
    local sa_tier=${5}
    local sa_public=${6}

    { \
        [[ ${rg} != "" ]] && \
        [[ ${location} != "" ]] && \
        [[ ${sa_name} != "" ]] && \
        [[ ${sa_sku} != "" ]] && \
        [[ ${sa_tier} != "" ]] \
        [[ ${sa_public} != "" ]] \
    } || { log_error "Function argument missing"; }

    run az provider register \
        --namespace 'Microsoft.Storage' \
        --wait \
        --consent-to-permissions
    log_info "Provider registered successfully"

    local sa_name_found=$(az storage account list |jq -r ".[] | select(.name == \"${sa_name}\") | .id")
    
    # early exit if resource already exists...
    [[ "${sa_name_found}" != "" ]] && \
        { log_info "Storage account '${sa_name}' already created"; return; }

    # ...create resource otherwise
    run az storage account create \
        --resource-group ${rg} \
        --location "${location}" \
        --name ${sa_name} \
        --sku "${sa_sku}" \
        --access-tier "${sa_tier}" \
        --allow-blob-public-access ${sa_public}

    log_info "Storage account '${sa_name}' created successfully"
}

function azure_create_sa_container() {
    log_info "Create storage account container..."

    local sa_name=${1}
    local sa_container_name=${2}

    { \
        [[ ${sa_name} != "" ]] && \
        [[ ${sa_container_name} != "" ]] && \
    } || { log_error "Function argument missing"; }

    local sa_container_name_found=$(az storage container list --account-name ${sa_name} --auth-mode login |jq ".[] | select(.name == \"${sa_container_name}\")")
    
    # early exit if resource already exists...
    [[ "${sa_container_name_found}" != "" ]] && \
        { log_info "Storage account container '${sa_container_name}' already created"; return; }

    # ...create resource otherwise
    local key=$(az storage account keys list --account-name ${sa_name} --query '[0].value' -o tsv)
    [[ ${key} != "" ]] || { errorout "Storage account key not found"; }

    run az storage container create \
        --name ${sa_container_name} \
        --account-name ${sa_name} \        
        --account-key ${key}

    log_info "Storage account container '${sa_container_name}' created successfully"
}

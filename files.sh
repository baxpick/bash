# include guard
if [[ -n "$_FILES_SH_INCLUDED" ]]; then
  return
fi
_FILES_SH_INCLUDED=1

# absolute path to root folder
if [[ "${FOLDER_bash}" == "" ]]; then
    echo "FOLDER_bash not set"
    exit 1
fi

# includes
# ########

source "${FOLDER_bash}/sanity.sh"
source "${FOLDER_bash}/logging.sh"

# functions
# #########

# what: get value for key from a key=value file (KEY1 = "value1")
# usage: VALUE1=$(value_from /path/to/key_value_file KEY1)
function value_from {
    [[ "${1}" != "" ]] || log_error "empty argument"
    [[ "${2}" != "" ]] || log_error "empty argument"

    local file=$1
    local find_key=$2

    ensure_file "${file}"
    ensure_command perl

    while IFS='=' read -r key value; do
        read -r key <<< "$key"
        read -r value <<< "$value"
        value=$(echo "$value" | perl -p -e "s/['\"](.*)['\"]/\1/g")
        [[ "${key}" == "${find_key}" ]] && { printf "%s" "$value"; return; }
    done < "${file}"
    printf ""
}

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

source "${FOLDER_bash}/system.sh"
source "${FOLDER_bash}/logging.sh"

# functions
# #########

# what: get value for key from a key=value file (KEY1 = "value1")
# usage: VALUE1=$(value_from --file /path/to/key_value_file --findKey KEY1)
function value_from {

    # defaults
    local file=""
    local find_key=""

    # Parse named arguments
    while [[ $# -gt 0 ]]; do
        key="$1"
        case $key in
            --file)
            file="$2"
            shift
            shift
            ;;
            --findKey)
            find_key="$2"
            shift
            shift
            ;;
        esac
    done

    { \
        [[ ${file} != "" ]] && \
        [[ ${find_key} != "" ]] \
    } || { log_error "Function argument missing"; }

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

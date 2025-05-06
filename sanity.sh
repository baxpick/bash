# include guard
if [[ -n "$_SANITY_SH_INCLUDED" ]]; then
  return
fi
_SANITY_SH_INCLUDED=1

# absolute path to root folder
if [[ "${FOLDER_bash}" == "" ]]; then
    echo "FOLDER_bash not set"
    exit 1
fi

# includes
# ########

source "${FOLDER_bash}/logging.sh"

# functions
# #########

function ensure_command() {
    [[ "${1}" != "" ]] || log_error "empty argument"
    command -v "${1}" >/dev/null 2>&1 || log_error "Command '${1}' not found"
}

function ensure_file() {
    [[ "${1}" != "" ]] || log_error "empty argument"
    [[ -f "${1}" ]] || log_error "File '${1}' not found"
}

function ensure_folder() {
    [[ "${1}" != "" ]] || log_error "empty argument"
    [[ -d "${1}" ]] || log_error "Folder '${1}' not found"
}

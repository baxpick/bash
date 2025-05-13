# include guard
if [[ -n "$_SYSTEM_SH_INCLUDED" ]]; then
  return
fi
_SYSTEM_SH_INCLUDED=1

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

get_cpu_cores() {
    local cores=1
    if [[ "$(uname)" == "Darwin" ]]; then
        cores=$(sysctl -n hw.ncpu 2>/dev/null || echo 1)
    elif [[ "$(uname)" == "Linux" ]]; then
        cores=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || nproc 2>/dev/null || echo 1)
    else
        cores=1
    fi
    echo "$cores"
}

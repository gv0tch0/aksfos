#set -x
set -e
data_root=$1
if [[ ! -d ${data_root} ]]; then
    echo "error: first arg (${data_root}) needs to be an existing directory."
fi


#set -x
set -e

arg=$1
if [[ ${arg} =~ ^.*\ +.*$ ]]; then
    echo "'${arg}' has space."
fi


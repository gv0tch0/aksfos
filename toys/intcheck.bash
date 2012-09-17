num_nodes=$1
if [[ ${num_nodes} != [0-9]* ]]; then
    echo "error: first arg (${num_nodes}) needs to be a positive integer."
fi

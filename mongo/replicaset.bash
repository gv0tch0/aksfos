#!/usr/bin/env bash
# creates data directories for, spawns and
# organizes the necessary mongo processes
# for a mongo replica set.
# all of that is done in the local machine
# and helps with spawning a mongo replica
# set.
#
# prerequisites:
#  - bash 4+
#  - mongo executables are on the path
#  - ports {50000..<nodes>}
#    are available to be bound to

#set -x # this makes bash print all the commands that
       # it is executing
set -e # this makes bash exit as soon as any of the
       # commands it ran returned non-zero

#globals
data_root=
num_of_nodes=
sleep_secs=7
rsetid=rs_`date +%s`
rset_file=${rsetid}.js
start_file=${rsetid}.start
stop_file=${rsetid}.stop

#echoes the usage info
function usage() {
    me=`basename $0`
    echo "usage: ${me} [num-of-nodes] [data-root]"
    echo "  [num-of-nodes] (required) the number of nodes in the replica set."
    echo "                 valid range: [2,7]. in case of an even number of"
    echo "                 nodes an extra arbiter-only mongod process will be"
    echo "                 spawned to break the primary election votes ties."
    echo "  [data-root]    (required) the directory that hosts the mongo data"
    echo "                 for each node in the replica set."
}

#echos the first argument that was passed to it
#removing the trailing slash if any
function trim_trailing_slash() {
    regex="^(.*)/$"
    if [[ $1 =~ $regex ]]; then
        echo ${BASH_REMATCH[1]}
    else
        echo $1
    fi
}

#grabs the number of shards and the number
#of nodes in the shard replica set from the
#command line
function process_args() {
    if [ $# -ne 2 ]; then
        echo "ERROR: i need two arguments to run."
        usage
        exit 1
    else
        num_of_nodes=$1
        if [ ${num_of_nodes} -lt 2 ] || [ ${num_of_nodes} -gt 7 ]; then
            echo "ERROR: the number of nodes per shard replica set '${num_of_nodes}' is outside of the valid range."
            usage
            exit 1
        fi
        data_root=`trim_trailing_slash $2`
        echo "will create a replica set with '${num_of_nodes}' nodes (an arbiter will be added if the"
        echo "nodes are even). the data will be hosted under the '${data_root}/${rsetid}' directory."
    fi
}

#generates the mongo replica set config file for
#the shard at the globally set shard_num
function generate_rset_config() {
    if [ -e ${rset_file} ]; then
        echo "WARNING: the mongo replica set configuration file '${rset_file}' exists and will be overwritten."
        echo "         its contents are:"
        cat ${rset_file}
        echo "         <end of existing '${rset_file}' contents>"
    fi

    local last_node_idx=-1
    let "last_node_idx = ${num_of_nodes} - 1"

    echo "config = { _id: \"${rsetid}\", members: [" > ${rset_file}
    for ((node = 0; node < ${num_of_nodes}; node++))
    do
        node_cfg="{_id: ${node}, host: \"127.0.0.1:5000${node}\"}"
        if [ ${node} -lt ${last_node_idx} ] || [ $(( ${num_of_nodes} % 2 )) -eq 0 ]; then
            node_cfg="${node_cfg},"
        fi
        echo ${node_cfg} >> ${rset_file}
    done
    if [ $(( ${num_of_nodes} % 2 )) -eq 0 ]; then
        echo "{_id: ${node}, host: \"127.0.0.1:5000${num_of_nodes}\", arbiterOnly: true}" >> ${rset_file}
    fi
    echo "]}" >> ${rset_file}

    echo "rs.initiate(config)" >> ${rset_file}
}

process_args "$@"

#create the start file
touch ${start_file}
chmod 755 ${start_file}
echo "#!/usr/bin/env bash" >> ${start_file}

#start the replica set for each shard
for ((node = 0; node < ${num_of_nodes}; node++))
do
    data_dir=${data_root}/${rsetid}/node${node}
    log_file=${data_dir}/mongod.log
    port=5000${node}
    mkdir -p ${data_dir}
    cmd="mongod --fork --logpath ${log_file} --port ${port} --replSet ${rsetid} --dbpath ${data_dir}"
    echo ${cmd} >> ${start_file}
    ${cmd}
done

#spawn an arbiter only mongod process if we otherwise would
#end up with an even number of nodes
if [ $(( ${num_of_nodes} % 2 )) -eq 0 ]; then
    data_dir=${data_root}/${rsetid}/arbiter
    log_file=${data_dir}/mongod.log
    port=5000${num_of_nodes}
    mkdir -p ${data_dir}
    cmd="mongod --fork --logpath ${log_file} --port ${port} --replSet ${rsetid} --dbpath ${data_dir}"
    echo ${cmd} >> ${start_file}
    ${cmd}
fi

#create the stop file
touch ${stop_file}
chmod 755 ${stop_file}
echo "#!/usr/bin/env bash" >> ${stop_file}
echo "ps ax | grep mongod | grep ${rsetid} | grep -v grep | sed 's/^[ \t]*//' | cut -d' ' -f1 | xargs kill -2" >> ${stop_file}

generate_rset_config

echo "letting the mongo processes start before applying the replica set configuration..."
sleep ${sleep_secs} 
mongo 127.0.0.1:50000 ${rsetid}.js

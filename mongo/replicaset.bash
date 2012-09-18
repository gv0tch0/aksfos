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

#this makes bash print all the commands that
#it is executing
#set -x

#this makes bash exit as soon as any of the
#commands it ran returned non-zero
set -e

#globals
data_root=
num_nodes=
rset_file=
start_file=
stop_file=
sleep_secs=7
rsetid=rs_`date +%s`

#host os detection
cygwin=false
osx=false
osname=`uname -s`
cygregex="^cygwin.*$"
osxregex="^darwin.*$"
shopt -s nocasematch
if [[ ${osname} =~ $cygregex ]]; then
    cygwin=true
fi
if [[ ${osname} =~ $osxregex ]]; then
    osx=true
fi

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

#echos the abolute path to the directory specified
#by the first argument passed in. used in an os x
#environment which wierd readlink implementation.
function abs_path() {
    if [ $# -ne 1 ]; then
        echo "FATAL: i accept 1 argument. i got $# arguments instead."
        exit 1
    fi

    cd $1
    result=`pwd -P`
    cd - > /dev/null &2>1
    echo ${result}
}

#grabs the number of nodes and the data root directory
#from the command line
function process_args() {
    if [ $# -ne 2 ]; then
        echo "ERROR: i need 2 arguments to run. i got $# instead."
        usage
        exit 1
    fi

    num_nodes=$1
    if [[ ${num_nodes} != [0-9]* ]] || [ ${num_nodes} -lt 2 ] || [ ${num_nodes} -gt 7 ]; then
        echo "ERROR: the number of nodes for the replica set '${num_nodes}' is outside of the valid range."
        usage
        exit 1
    fi

    if [[ ! -d $2 ]]; then
        echo "ERROR: the second argument ('$2') must be a directory."
        usage
        exit 1
    fi
    if ${osx}; then
        data_root=`abs_path $2`
    else
        data_root=`readlink -f $2`
    fi

    echo "will create a replica set with '${num_nodes}' nodes (an arbiter will be added if the"
    echo "nodes are even). the data will be hosted under the '${data_root}/${rsetid}' directory."
    echo "the control files will be hosted under the '${data_root}' directory."

    rset_file=${data_root}/${rsetid}.js
    start_file=${data_root}/${rsetid}.start
    stop_file=${data_root}/${rsetid}.stop
}

#generates the mongo replica set config file
function generate_rset_config() {
    if [ -e ${rset_file} ]; then
        echo "WARNING: the mongo replica set configuration file '${rset_file}' exists and will be overwritten."
        echo "         its contents are:"
        cat ${rset_file}
        echo "         <end of existing '${rset_file}' contents>"
    fi

    local last_node_idx=-1
    let "last_node_idx = ${num_nodes} - 1"

    echo "config = { _id: \"${rsetid}\", members: [" > ${rset_file}
    for ((node = 0; node < ${num_nodes}; node++))
    do
        node_cfg="{_id: ${node}, host: \"127.0.0.1:5000${node}\"}"
        if [ ${node} -lt ${last_node_idx} ] || [ $(( ${num_nodes} % 2 )) -eq 0 ]; then
            node_cfg="${node_cfg},"
        fi
        echo ${node_cfg} >> ${rset_file}
    done
    if [ $(( ${num_nodes} % 2 )) -eq 0 ]; then
        echo "{_id: ${node}, host: \"127.0.0.1:5000${num_nodes}\", arbiterOnly: true}" >> ${rset_file}
    fi
    echo "]}" >> ${rset_file}

    echo "rs.initiate(config)" >> ${rset_file}
}

#records the mongod start command in the start control file.
function cmd_mongod() {
    if [ $# -ne 2 ]; then
        echo "FATAL: i need two arguments to start a mongod (the node number and name). i got $# arguments instead."
        exit 1
    fi

    node_num=$1
    if [[ ${node_num} != [0-9] ]]; then
        echo "FATAL: the node number ('${node_num}') is outside of the valid range ('[0-9]')."
        exit 1
    fi

    node_name=$2
    if [[ ${node_name} =~ ^.*\ +.*$ ]]; then
        echo "FATAL: the node name ('${node_name}') must not contain white space."
        exit 1
    fi

    data_dir=${data_root}/${rsetid}/${node_name}
    log_file=${data_dir}/mongod.log
    outerr_file=${data_dir}/outerr.log
    port=5000${node_num}
    mkdir -p ${data_dir}
    cmd="mongod --fork --logpath ${log_file} --port ${port} --replSet ${rsetid} --dbpath ${data_dir}"
    if ${cygwin}; then
        log_file='`cygpath -w '${log_file}'`'
        data_dir='`cygpath -w '${data_dir}'`'
        outerr_file='`cygpath -w '${outerr_file}'`'
        cmd="mongod --logpath ${log_file} --port ${port} --replSet ${rsetid} --dbpath ${data_dir} > ${outerr_file} 2>&1 &"
    fi
    echo ${cmd} >> ${start_file}
}

# get and validate the arguments
process_args "$@"

#create the start file
touch ${start_file}
chmod 755 ${start_file}
echo "#!/usr/bin/env bash" >> ${start_file}

#start mongo for each node in the set
for ((node = 0; node < ${num_nodes}; node++))
do
    cmd_mongod "${node}" "node${node}"
done

#spawn an arbiter only mongod process if we otherwise would
#end up with an even number of nodes
if [ $(( ${num_nodes} % 2 )) -eq 0 ]; then
    cmd_mongod "${num_nodes}" "arbiter"
fi

#create the stop file
touch ${stop_file}
chmod 755 ${stop_file}
echo "#!/usr/bin/env bash" >> ${stop_file}
if ${cygwin}; then
    echo "echo \"Please manually observe the mongod processes, decide which ones apply\"" >> ${stop_file}
    echo "echo \"to the replicaset in question, and stop them by hand.\"" >> ${stop_file}
else
    echo "ps ax | grep mongod | grep ${rsetid} | grep -v grep | sed 's/^[ \t]*//' | cut -d' ' -f1 | xargs kill -2" >> ${stop_file}
fi

#generate the replica set config script
generate_rset_config

#start the mongods and apply the replica set config script
echo "starting the mongod processes..."
sh ${start_file}
wait `echo $!`
#TODO get smarter as to how long to wait before trying to apply the replica set
#     configuration by for example asking the mongod-s what state they are in.
echo "letting the mongod processes start before applying the replica set configuration..."
sleep ${sleep_secs} 
mongo 127.0.0.1:50000 ${rset_file}

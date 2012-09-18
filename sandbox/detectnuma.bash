#!/usr/bin/env bash

set -x
set -e

numa=$(lscpu | grep -i numa | cut -d ":" -f 2 | sed 's/ //g')
if [[ $numa == [0-9]* ]] && [ $numa -gt 0 ]; then
    echo "we are on a NUMA (number of nodes: $numa)."
else
    echo "not running on a NUMA (number of nodes: $numa)."
fi

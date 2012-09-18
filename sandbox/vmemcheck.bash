#!/usr/bin/env bash

#set -x
set -e

if [ $(ulimit -a | grep -i "virtual memory" | grep -i "unlimited" | wc -l) -eq 0 ]; then
    echo "we are vmem limited."
else
    echo "we are vmem unlimited."
fi

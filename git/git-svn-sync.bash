#!/usr/bin/env bash

#1 takes the svn repo url as a parameter
#2 takes the directory that hosts the `git svn' clones as a parameter
#3 for each project in the svn repo sees if a git project exists in the `git svn' clones
#    if a git clone exists does a `git spull'
#    otherwise does a `git svn clone -s'

# Dependencies
# - Git and svn are installed.
# - `spull' is defined as `git-svn fetch && git-svn rebase --local' in the user's gitconfig

# TODO
# * Gracefully handle dirty trees. As in `git spull' fails when the tree is dirty. One
#   option will be to stash the changes, do the spull, and unstash the changes. That
#   probably is a bad option though as the unstashing may run into conflicts. Another
#   option would be to WARN and not attempt the `git spull'.
# * Fork a sub-shell for each project which does the work outlined in step 3 above.
#   This will definitely speed things up, assuming the svn repo does not slow down because
#   of the concurrent requests.

function usage() {
    me=`basename $0`
    echo "usage: $me [svn-url] <local-project-dir>"
    echo "  [svn-url]           the required URL of the svn repository that is listed for projects to be cloned/refreshed"
    echo "  <local-project-dir> the optional directory that hosts the 'git svn'-clones; the current directory if omitted"
}

function process_args() {
    if [ $# -eq 1 ]; then
        svn_url=$1
        prj_dir=`pwd`
    elif [ $# -eq 2 ]; then
        svn_url=$1
        prj_dir=$2
    else
        usage
        exit 1
    fi
}

function trim_trailing_slash() {
    regex="(.*)/"
    if [[ $1 =~ $regex ]]; then
        echo ${BASH_REMATCH[1]}
    else
        echo $1
    fi
}

function collect_svn_projects() {
    echo "INFO: collecting the svn project list from '$svn_url'..."
    local i=0
    local prjct
    for prjct in `svn list $svn_url`; do
        svn_prjcts[i]=`trim_trailing_slash $prjct`
        let i++
    done
    echo $svn_prjcts
}

function ensure_project_dir() {
    if [ ! -d $prj_dir ]; then
        echo "INFO: the provided project directory '$prj_dir' does not exist. i will try to create it..."
        mkdir -p $prj_dir
        mkdir_exit=$?
        if [ $mkdir_exit -ne 0 ]; then
            echo "ERROR: could not create the project directory '$prj_dir'..."
            exit $mkdir_exit
        fi
    fi
}

process_args $@
ensure_project_dir
collect_svn_projects
cd $prj_dir
for prjct in "${svn_prjcts[@]}"; do
    if [ -d $prjct ]; then
        echo "INFO: $prjct directory exists. will try to refresh it if it is a git svn clone..."
        if [ ! -d $prjct/.git ]; then
            echo "WARNING: $prjct does not appear to be a git repository. skipping it..."
        else
            echo "INFO: $prjct is a git repository. updating the current branch..."
            cd $prjct
            git spull
            cd ..
        fi
    else
        echo "INFO: $prjct does not exist. cloning it..."
        git svn clone -s $svn_url/$prjct
    fi
done


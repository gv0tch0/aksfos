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
# * Do not assume a standard svn repo structure. Instead `svn list` and only do standard
#   if trunk|tags|branches are present. Even better would be to do a discovery step of the
#   svn repo's structure and then clone at the right levels.
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
            echo "ERROR: could not create the project directory '$prj_dir'."
            exit $mkdir_exit
        else
            echo "INFO: successfully created the '$prj_dir' directory."
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
            echo "WARN: $prjct does not appear to be a git repository. skipping it."
        else
            echo "INFO: $prjct is a git repository. will try to update the current branch..."
            cd $prjct
            if [ $(git status 2> /dev/null | tail -n1) != "nothing to commit, working directory clean" ]; then
                echo "INFO: the git clone is clean. pulling latest svn changes..."
                git spull
            else
                echo "WARN: the git clone is dirty. please commit/revert/stash changes and pull manually."
            fi
            cd ..
        fi
    else
        echo "INFO: $prjct does not exist. cloning it..."
        git svn clone -s $svn_url/$prjct
    fi
done


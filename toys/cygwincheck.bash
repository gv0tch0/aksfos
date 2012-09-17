#set -x
#set -e
uname_s=`uname -s`
regex="^cygwin(.*)$"
shopt -s nocasematch
cygwin=false
if [[ $uname_s =~ $regex ]]; then
    cygwin=true
fi

if ${cygwin}; then
    echo "we are on cygwin (${uname_s})"
else
    echo "we are on ${uname_s}"
fi


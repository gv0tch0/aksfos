#set -e
#set -x

var="varval"

file="/home/kolevn"
file='`cygpath -w '$file'`'
cmd="foo $file foo $var bar"
echo $cmd

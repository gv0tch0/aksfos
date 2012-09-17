#set -x
set -e

function func() {
    if [ $# -ne 3 ]; then
        echo "error: func expects 3 args."
        exit 1
    fi

    echo $1' '$2' '$3
}
echo "calling func with 2 args"
func "foo" "bar"
echo "calling func with 3 args"
func "foo" "bar" "baz"

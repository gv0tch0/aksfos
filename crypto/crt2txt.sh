#!/usr/bin/env bash
set -e

if [ $# -ne 1 ]; then
  echo "ERROR: I demand one argument. I got $# instead ($@)."
  echo "usage: $0 /path/to/cert"
  exit 1
fi

if [ ! -f "$1" ]; then
  echo "ERROR: The '$1' argument is not a regular file that I can read."
  echo "usage: $0 /path/to/cert"
  exit 1
fi

epoch=$(date '+%s')

bemre="-----.* CERTIFICATE-----"
trimmed="$1.trimmed.$epoch"
touch $trimmed
while read line
do
  if [[ $line =~ $bemre ]]; then
    continue
  fi
  echo $line >> $trimmed
done < $1

decoded="$1.trimmed.decoded.$epoch"
base64 -D -i $trimmed -o $decoded
openssl x509 -inform DER -text -in $decoded

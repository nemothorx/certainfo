#!/bin/bash

host=${1:-help}
port=${2:-443}

case $host in 
    help|-h|--help) 
        echo "
Print the details of every cert in a chain on a remote server, 
not just the first (as is openssl s_client default). 

Handles any port with SSL. Defaults to 443. 
If port is 443, will also give https headers for the server. 

Output is markdown. (acceptable conversion to html via pandoc) 

Usage: $(basename $0) server [port]
    "
    exit 0
    ;;

esac


do_chainget() {
    # get info from each cert in a chain
    # md5 fingerprint is for fetchmail needs, otherwise it defaults to SHA1
    awk 'BEGIN { pipe="openssl x509 -noout -subject -dates -serial -fingerprint -md5  -issuer"}
      /BEGIN CERT/ { count++ ; printf count".\n" }
      /^-+BEGIN CERT/,/^-+END CERT/ { print | pipe }
      /^-+END CERT/                 { close(pipe)  }'
}

echo "# Full cert chain for $host:$port on: $(date)"
echo ""

# extra info for some ports
case $port in
    443)
        echo "## HTTP headers"
        curl -s -k -I https://$host:$port | sed -e 's/^/    /g'
        ;;
esac

echo "## Certificates"
openssl s_client -connect $host:$port -servername $host -showcerts </dev/null 2>/dev/null | do_chainget | awk '{ if (/=/) { printf "        " } ; { print } }'

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

Output is markdown. (and tested for conversion with pandoc) 
eg:
$0 uuuuuu.au | pandoc -f markdown -o uuuuuu.au-ssl.html
$0 uuuuuu.au | pandoc -f markdown --pdf-engine=xelatex -o ssl.pdf
$0 uuuuuu.au | pandoc -f markdown --pdf-engine=pdfroff -o uuuuuu.au-ssl.pdf
$0 uuuuuu.au | pandoc -f markdown --pdf-engine=xelatex -V geometry:'top=2cm, bottom=1.5cm, left=2cm, right=2cm' -o uuuuuu.au-ssl.pdf

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

echo "# Full cert chain for $host:$port"
echo "Generated on: $(date)"
echo ""

echo "## Certificates"
openssl s_client -connect $host:$port -servername $host -showcerts </dev/null 2>/dev/null | do_chainget | awk '{ if (/=/) { printf "        " } ; { print } }'

echo ""

# extra info for some ports
case $port in
    443)
        echo "# Additional info"
        echo ""

        echo "## HTTP headers"
        echo ""
        curl -s -k -I http://$host/ | sed -e 's/^/    /g'

        echo "## HTTPS headers"
        echo ""
        curl -s -k -I https://$host:$port/ | sed -e 's/^/    /g'
        ;;
esac


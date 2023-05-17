#!/bin/bash

host=${1:-www.google.com}
port=${2:-443}


do_chainget() {
    # get info from each cert in a chain
    # other useful options:
    #   -serial
    awk 'BEGIN { pipe="openssl x509 -noout -subject -dates -serial -fingerprint -md5 -ext subjectAltName -issuer"}
      /BEGIN CERT/ { count++ ; printf count".\n" }
      /^-+BEGIN CERT/,/^-+END CERT/ { print | pipe }
      /^-+END CERT/                 { close(pipe) }' 
}

echo "# Certificate information for $host:$port as of $(date)"
host $host
echo ""
openssl s_client -connect $host:$port  -servername $host -showcerts </dev/null 2>/dev/null | do_chainget | awk '{ if (!/\.$/) { printf "        " } ; { print } }' | fmt -s # sed -e 's/, DNS/,\n            DNS/g'
echo ""


# TODO: this assumes https. but it should be smarter so we can do IMAPS, POP3S, etc
if [ "$port" == "443" ] ; then
    echo "# HTTP headers for $host:$port"
    echo ""
    curl -s -k -I https://$host:$port
fi

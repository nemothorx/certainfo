#!/bin/bash

host=${1:-www.google.com}
port=${2:-443}


do_chainget() {
    # get info from each cert in a chain
    # other useful options:
    #   -serial
    awk 'BEGIN { pipe="openssl x509 -noout -subject -dates -issuer"}
      /BEGIN CERT/ { count++ ; printf "|"count": " }
      /^-+BEGIN CERT/,/^-+END CERT/ { print | pipe }
      /^-+END CERT/                 { close(pipe); printf("~")}' | grep -v notBefore | tr "\n" "|" | sed -e 's/|~|/~/g' | tr "~" "\n" | column -t -s'|'
}

date
echo ""
# TODO: this assumes https. but it should be smarter so we can do IMAPS, POP3S, etc
#if [ "$port" == "443" ] ; then
#    echo "# HTTP headers for $host:$port"
#    curl -k -I https://$host:$port
#    echo ""
#fi
echo "# Certificate information for $host:$port"
openssl s_client -connect $host:$port  -servername $host -showcerts </dev/null 2>/dev/null | do_chainget | sed -e "s/^/  /g"

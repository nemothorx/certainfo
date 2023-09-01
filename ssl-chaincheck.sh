#!/bin/bash

extopts=""

if [ -z "$1" ] ; then
    echo "Please give a .pem/.crt file, or domain"
    exit 1
fi

if [ $1 == "-v" ] ; then
    verbose=true
    shift
fi

certat=${1:-help}
port=${2:-443}

case $certat in 
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
   or: $(basename $0) /path/to/cert.pem (or .crt)
    "
    exit 0
    ;;

esac


do_chainget() {
    # get info from each cert in a chain
    # md5 fingerprint is for fetchmail needs, otherwise it defaults to SHA1
    awk 'BEGIN { pipe="openssl x509 -noout -subject -dates -serial -fingerprint -md5 -ext subjectAltName -issuer"}
      /BEGIN CERT/ { count++ ; printf count".\n" }
      /^-+BEGIN CERT/,/^-+END CERT/ { print | pipe }
      /^-+END CERT/                 { close(pipe)  }'
}


if [ -e ${certat} ] ; then
    # we're inspecting a local file
    echo "# Cert inspection of file: ${certat}"
    echo "Generated on: $(date)"
    echo ""
    cat "$certat" | do_chainget 2>/dev/null | awk '{ if (!/\.$/) { printf "        " } ; { print } }' | fmt -s
    echo ""
    echo "# Additional info"
    echo ""
    echo "$HOSTNAME:$(readlink -f ${certat})"
    echo "$(ls -l "$(readlink -f "${certat}")")"
else
    # we're loading cert from online:
    echo "# Cert inspection of URI: $certat:$port"
    case $port in
        25|587) 
            extopts="-starttls smtp" 
            ;;
        110)
            extopts="-starttls pop3" 
            ;;
        143)
            extopts="-starttls imap" 
            ;;
    esac
    [ -n "$extopts" ] && echo -e "Cert on port $port obtained using \`$extopts\` option\n"
    echo "Generated on: $(date)"

    echo ""
    echo "## Certificates"
    echo ""
    openssl s_client -connect $certat:$port -servername $certat $extopts -showcerts </dev/null 2>/dev/null | do_chainget 2>/dev/null | awk '{ if (!/\.$/) { printf "        " } ; { print } }' | fmt -s 

    echo ""

    if [ "$verbose" == "true" ] ; then
        # extra info for some ports
        case $port in
            443)
                echo "# Additional info"
                echo ""

                echo "## HTTP headers"
                echo ""
                curl -s -k -I http://$certat/ | sed -e 's/^/    /g'

                echo "## HTTPS headers"
                echo ""
                curl -s -k -I https://$certat:$port/ | sed -e 's/^/    /g'
                ;;
        esac
    fi
fi

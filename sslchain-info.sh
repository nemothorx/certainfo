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
$0 -v example.com | pandoc -f markdown -o example.com-ssl.html
$0 -v example.com | pandoc -f markdown --pdf-engine=xelatex -o example.com-ssl-xelatex.pdf
$0 -v example.com | pandoc -f markdown --pdf-engine=pdfroff -o example.com-ssl-pdfroff.pdf
$0 -v example.com | pandoc -f markdown --pdf-engine=xelatex -V geometry:'top=2cm, bottom=1.5cm, left=2cm, right=2cm' -o example.com-ssl-xelatex-V.pdf

Usage: $(basename $0) server [port]
   or: $(basename $0) /path/to/cert.pem (or .crt)
    "
    exit 0
    ;;

esac


do_chainget() {
    # get info from each cert in a chain
    # A note on fingerprint hash options:
    # -md5 = legacy fetchmail compatible (6.4 or earlier?)
    # -sha1 = openssl default
    # -sha256 = best for hash uniqueness, but risks loses data wrapping on PDF
    awk 'BEGIN { pipe="openssl x509 -noout -subject -dates -serial -fingerprint -md5 -ext subjectAltName -issuer"}
      /BEGIN CERT/ { count++ ; printf count".\n" }
      /^-+BEGIN CERT/,/^-+END CERT/ { print | pipe }
      /^-+END CERT/                 { close(pipe)  }'
}


if [ -e ${certat} ] ; then
    # we're inspecting a local file
    echo "# Certificate inspection of file: ${certat}"
    echo "Generated on: $(date)"
    echo ""
    echo "## Certificates"
    echo ""
    cat "$certat" | do_chainget 2>/dev/null | awk '{ if (!/\.$/) { printf "        " } ; { print } }' | fmt -s
    echo ""
    echo "# Additional info"
    echo ""
    echo "        $HOSTNAME:$(readlink -f ${certat})"
    echo ""
    echo "        $(ls -l "$(readlink -f "${certat}")")"
    echo ""
else
    # we're loading cert from online:
    echo "# SSL inspection of URI: $certat:$port"
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
        # TODO: other ports openssl can do. ldap, ftp, xmpp, nntp
    esac
    [ -n "$extopts" ] && echo -e "Cert on port $port obtained using \`$extopts\` option\n"
    echo "Generated on: $(date)"
    echo ""

    echo "## Certificates"
    echo ""
    openssl s_client -connect $certat:$port -servername $certat $extopts -showcerts </dev/null 2>/dev/null | do_chainget 2>/dev/null | awk '{ if (!/\.$/) { printf "        " } ; { print } }' | sed -e 's/, DNS:/ DNS:/g ; s/DNS:/\n            DNS: /g' | fmt -p "DNS: " | grep .
    # final formatting was originally `fmt -s` (format lines by folding on spaces, and retain indenting.)
    # ...But this was folding long subject/issuer names also.
    # This sed|fmt|grep method targets the SAN DNS entries only and makes them be one-per-line, whilst removing redundant "DNS:" prefixes and blank lines
    #
    # TODO: Consider handle non-DNS values sanely too. As of writing, not seen any in the wild. x509v3_config(5ssl) says
    # > Subject Alternative Name
    # >   This is a multi-valued extension that supports
    # >   several types of name identifier, including
    # >   - email (an email address),
    # >   - URI (a uniform resource indicator),
    # >   - DNS (a DNS domain name),
    # >   - RID (a registered ID: OBJECT IDENTIFIER),
    # >   - IP (an IP address),
    # >   - dirName (a distinguished name), and
    # >   - otherName.
    #
    echo ""

    if [ "$verbose" == "true" ] ; then
    # verbose info works backwards from SSL-focused stuff to the basics
    # TODO: progressive options: -v for https, -vv adds http, and -vvv adds DNS
        echo "# Additional info"
        echo ""
        # extra info for some ports
        case $port in
            443)
                # TODO: would be nice to find a way to wrap http headers in an smtp/ldap esque way sanely. But `fmt -s` doesn't have an option to add indent on wrapped lines. Currently only a data-loss issue with PDF formatting in pandoc
                # ...potentially solvable with pandoc options: https://tex.stackexchange.com/questions/323329/pandoc-code-blocks-in-markdown-with-very-long-lines-get-cut-off-when-outputting (not tested)
                echo "## HTTPS headers"
                echo ""
                curl -s -k -I --connect-timeout 1 -m 2 https://$certat:$port/ | sed -e 's/^/        /g'

                echo "## HTTP headers"
                echo ""
                curl -s -k -I --connect-timeout 1 -m 2 http://$certat/ | sed -e 's/^/        /g'

                ;;
            # TODO: extra info for other protocols (banner from IMAP, POP, SMTP)
        esac
        echo "## DNS"
        host $certat | sed -e 's/^/        /g'
        echo ""
    fi
fi

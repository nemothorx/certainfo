#!/bin/bash

host=${1:-www.google.com}
port=${2:-443}


do_chainget() {
    # get info from each cert in a chain
    # other useful options:
    #   -serial
    awk 'BEGIN { 
			pipe="openssl x509 -noout -text -serial -fingerprint -md5 -dates -certopt no_header,no_version,no_serial,no_signame,no_validity,no_pubkey,no_sigdump" 
		} 
      /^-+BEGIN CERT/,/^-+END CERT/ { print | pipe }
      /^-+END CERT/                 { close(pipe) ; printf "\n~\n" } ' | grep -E 'Issuer:|Subject:|DNS:|^[a-z0-9A-Z~]' | sed -e 's/^\s*//g' # we just blat the data out with '~' being cert delimiter
}

do_mkpretty() {
# first awk gets them in order
# second awk gets the indenting good
	awk '{
			if ( /Subject:/ ) { subject=$0 }
			if ( /DNS:/ ) { dns=$0 }
			if ( /notBefore=/ ) { notbefore=$0 }
			if ( /notAfter=/ ) { notafter=$0 }
			if ( /serial=/ ) { serial=$0 }
			if ( /MD5 Fingerprint=/ ) { md5=$0 }
			if ( /Issuer:/ ) { issuer=$0 }
			if ( /~/ ) { 
				count++
				printf "\n"count".\n"subject"\n"dns"\n"notbefore"\n"notafter"\n"serial"\n"md5"\n"issuer"\n"
				dns=""
			}
		}
    '  | grep . |  awk '
    BEGIN {
        fmt="fmt -s"
    }
    {
        if ( (!/\.$/) && (!/DNS/) ) {
            printf "        "
        }
        if (/DNS/) {
                printf "            " $0 | fmt ; close(fmt)
        } else {
			print
        }
    }'

}

echo "# Certificate information for $host:$port as of $(date)"
openssl s_client -connect $host:$port  -servername $host -showcerts </dev/null 2>/dev/null | do_chainget | do_mkpretty
#/Subject:/ {print}
#/DNS:/ {print}
#/notBefore=/ {print}
#/notAfter=/ {print}
#/serial=/ {print}
#/MD5 Fingerprint=/ {print}
#/Issuer:/ {print}
#{print}
#'


# | awk '{ if (!/\.$/) { printf "        " } ; { print } }'

# this awk makes them in the right order. hopefully. 

# | tr "\n" "|" | sed -e 's/|~|/~/g ; s/issuer/\n    issuer/g' | tr "~" "\n" | column -t -s'|'


echo ""
# TODO: this assumes https. but it should be smarter so we can do IMAPS, POP3S, etc
if [ "$port" == "443" ] ; then
    echo "# Additionally: HTTP headers for $host:$port"
    curl -s -k -I https://$host:$port
    echo ""
fi

exit 0


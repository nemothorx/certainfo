#!/bin/bash

echo ""

# multiline capture derived from https://stackoverflow.com/questions/25907394/multi-line-awk-capture
cat $1 | awk '
    BEGIN {
        maininfo="openssl x509 -noout -subject -dates -serial -fingerprint -md5 -ext subjectAltName -issuer 2>/dev/null"
        csrinfo="openssl req -noout -text 2>/dev/null | grep -i -E \"subject:|DNS:\""
        crtmod="openssl x509 -noout -modulus | md5sum"
        csrmod="openssl req -noout -modulus 2>/dev/null | md5sum"
        keymod="openssl rsa -noout -modulus | md5sum"
    }

    /-----BEGIN/ {
        count++ ; printf count".\n"
        out=$0
        next
    }

    /-----END( RSA)? PRIVATE KEY-----/ {
        out=out RS $0
        printf "PRIVATE KEY (modulus|md5): "
        print out | keymod ; close(keymod)
        out=""
    }
    /-----END CERTIFICATE REQUEST-----/ {
        out=out RS $0
        print out | csrinfo ; close(csrinfo)
        printf "CRT REQUEST (modulus|md5): "
        print out | csrmod ; close(csrmod)
        out=""
    }
    /-----END CERTIFICATE-----/ {
        out=out RS $0
        print out | maininfo ; close(maininfo)
        printf "CERTIFICATE (modulus|md5): "
        print out | crtmod ; close(crtmod)
        out=""
    }

    {
        if (length(out))out=out RS $0
    }
    '  | awk '
    BEGIN {
        fmt="fmt -s"
    }
    {
        if ( (!/\.$/) && (!/DNS/) ) {
            printf "        "
        }
        if (/DNS/) {
                printf "        " $0 | fmt ; close(fmt)
        } else {
            print
        }
    }'

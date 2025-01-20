#!/bin/bash

echo ""

# multiline capture derived from https://stackoverflow.com/questions/25907394/multi-line-awk-capture
cat $1 | awk '
    BEGIN {
        maininfo="openssl x509 -noout -subject -dates -serial -fingerprint -md5 -ext subjectAltName -issuer"
        keymod="openssl rsa -noout -modulus | md5sum"
        csrmod="openssl req -noout -modulus | md5sum"
        csrinfo="openssl req -noout -subject"
        crtmod="openssl x509 -noout -modulus | md5sum"
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
        printf "CRT REQUEST (modulus|md5): "
        print out | csrmod ; close(csrmod)
        print out | csrinfo ; close(csrinfo)
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

#!/bin/bash
cat $1 | awk 'BEGIN { ossl="openssl x509 -noout -subject -dates -serial -ext subjectAltName -issuer"}
/^-+BEGIN CERT/,/^-+END CERT/ { print | ossl }
/^-+END CERT/  { close(ossl); printf("\n")}'

#!/bin/bash

echo ""

#cat $1 | awk 'BEGIN { pipe="openssl x509 -noout -text -subject -serial -fingerprint -md5 -dates -issuer -certopt no_header,no_version,no_serial,no_signame,no_validity,no_pubkey,no_sigdump"}
#cat $1 | awk 'BEGIN { pipe="openssl x509 -noout -subject -serial -fingerprint -md5 -dates -issuer"}
#cat $1 | awk 'BEGIN { pipe="openssl x509 -noout -subject -serial -fingerprint -dates -issuer"}
cat $1 | awk 'BEGIN { pipe="openssl x509 -in /dev/stdin -noout -subject -ext subjectAltName -serial -fingerprint -dates -issuer"}
      /BEGIN CERT/ { count++ ; printf count".\n"}
      /^-+BEGIN CERT/,/^-+END CERT/ { print | pipe }
      /^-+END CERT/                 { close(pipe); printf("\n")}'  | awk '{ if (!/\.$/) { printf "        " } ; { print } }'

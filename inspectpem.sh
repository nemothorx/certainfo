#!/bin/bash

echo ""

cat $1 | awk 'BEGIN { pipe="openssl x509 -noout -subject -dates -serial -fingerprint -md5 -ext subjectAltName -issuer"}
      /BEGIN CERT/ { count++ ; printf count".\n"}
      /^-+BEGIN CERT/,/^-+END CERT/ { print | pipe }
      /^-+END CERT/                 { close(pipe); printf("\n")}'  | awk '{ if (!/\.$/) { printf "        " } ; { print } }' | fmt -s

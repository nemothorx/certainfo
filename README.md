# Certain Info

A collection of helper scripts to inspect SSL certificates. 

The original idea was to provides information about every certificate in an SSL chain, not just the first (as is `openssl` default)

This repo was originally constructed from various saved and 
rescovered-from-backups versions of the scripts. 

Reconstruction via git-timemachine from my neon-git tools. 

----

Note: The target names in this repo should follow the following scheme
- pem* = handle certificates in local files
- ssl* = handle certificates over the network 
- cert* = handle both


# The scripts in this repo are / planned to be:

## sslchain-info.sh
- network-focused crt/key inspector

## peminspect.sh
- no network MAXimal inspector of crt/key/csrs in a pem file

## certchain-info.sh (TODO ... this is a planned script!)
- merge all functionality in the previous 2 scripts
  - may supercede them. Will know when implemented

## pemnfo.sh
- no-network MINIMAL inspector of all certs in a pem file 
- minimum filesize for quick-and-dirty copypasta to remote systems

## ssl-nagcheck.sh - nagios compatible check of all relevant things
- mainly SSL based checks. validate the following: 
  - DNS of server resolves (ignore if reading PEM file with chain) (TODO)
  - CERT and CHAIN validity of dates (TODO for chain)
  - CERT validity of servername against SAN entries
  - CHAIN/LOCAL TRUST validity - cert links through intermediates to a local trust (TODO)
  - CONTENT check
- can also check port 80 (non-SSL) content, mainly with "is it redirecting as desired?" in mind, but not limited to that

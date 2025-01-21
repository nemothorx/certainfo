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

- sslchain-info.sh
  - Originally `ssl-chaincheck.sh`
  - network-focused crt/key inspector
  - Original awk core obtained from an online reference (likely stackoverflow or similar). Details now lost to history 
- peminspect.sh
  - Originally `certfile-check.sh`
  - no network MAXimal inspector of crt/key/csrs in a pem file
- certchain-info.sh (TODO: actually write this one!)
  - merge all functionality in the previous 2 scripts
    - may supercede them. Will know when implemented
- pemnfo.sh
  - Originally `inspectpem.sh`
  - no-network MINIMAL inspector of all certs in a pem file 
  - minimum filesize for quick-and-dirty copypasta to remote systems
- ssl-nagcheck.sh - nagios compatible check of all relevant things
  - SSL based check. validate the following: 
    - DNS of server resolves (ignore if reading PEM file with chain)
    - CERT validity servername against SAN entries
    - CERT and CHAIN validity of dates
    - CHAIN validity - cert links to intermediate, etc
    - LOCAL TRUST validity - validate that the chain links to a local trust
  - http content check if a server
    - http -> 301 to https?
    - load a deep URI and look for specific CONTENT
  - Note that most of these are TODO/wishlist items

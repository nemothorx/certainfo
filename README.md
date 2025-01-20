# Certain Info

A collection of helper scripts to inspect SSL certificates. 

Initial script was "ssl-chaincheck" with other scripts later. 

This repo is constructed from various saved and rescovered-from-backups versions of the scripts. Reconstruction via git-timemachine from my neon-git tools. 

## Historic names of scripts

In the historic repo construction phase, most scripts keep their original names, though with a few quirks:
- ssl-chaincheck.sh - some versions were "ssl-checkchain" for no obvious reason
- inspectpem.sh - a minimal inspector of certs in a pem file, however one original by this name was clearly derived from earlier certfilecheck.sh and so imported to the repo with that name

The repo construction also featured multiple versions of the above, so some are entered with _v2 or _v3 appended to their names. 

Other scripts kept their names, so are not detailed here. 

----

The scripts in this repo now are:

- ssl-chaincheck.sh - the original (sometimes as ssl-checkchain.sh) script. 3 versions.
- inspectpem.sh     - the minimal inspector of certs in a pem file. 2 versions.
- certfile-check.sh - a maximal inspector of cert info in a pem file
- ssl-nagcheck.sh   - a nagios check (with accompanying "cfg" file)


The target names I have planned for further cleanup and organisation of this repo are based on the following naming scheme: 
- pem* = handle certificates in local files
- ssl* = handle certificates over the network 
- cert* = handle both

Thus planned:
- sslchain-info.sh
  - derived from ssl-chaincheck.sh
  - network-focused crt/key inspector
- peminspect.sh
  - derived from certfile-check.sh
  - no network MAXimal inspector of crt/key/csrs in a pem file
- certchain-info.sh
  - merge all functionality in the previous 2 scripts
    - may supercede them. Will work that out as it's implemented
- pemnfo.sh
  - derived from inspectpem.sh
  - no-network MINIMAL inspector of all certs in a pem file 
  - minimum filesize for quick-and-dirty copypasta to remote systems
- ssl-nagcheck.sh - nagios compatible check of all relevant things (not renamed)
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


# The scripts in more detail

## SSL Chain Check `ssl-chaincheck.sh`

This script provides information about every certificate in an SSL chain, not just the first (as is `openssl` default)

Early versions pulled from various systems where the core idea was tweaked to suit local needs, without any central version control. Timing of these are vague, so I've set them to 1 Apr 2022, which feels roughly accurate, and also humorous.
Original awk core was obtained from an online reference, stackoverflow or similar, but now lost to history.

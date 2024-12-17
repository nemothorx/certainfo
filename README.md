# Certain Info

A collection of helper scripts to inspect SSL certificates. 

Initial script was "ssl-chaincheck" with other scripts later. 

This repo is constructed from various saved and rescovered-from-backups versions of the scripts. Reconstruction via git-timemachine from my neon-git tools. 

## Historic names of scripts

In the historic repo construction phase, most scripts keep their original names, though with a few quirks:
- ssl-chaincheck.sh - some versions were "ssl-checkchain" for no obvious reason
- inspectpem.sh - a minimal inspector of certs in a pem file, however one original by this name was clearly derived from earlier certfilecheck.sh and so imported to the repo with that name

The repo construction will also feature multiple versions of the above, so some are entered with _v2 or _v3 appended to their names. 

Other scripts kept their names, so are not detailed here. 


To start things off properly, the relevant readme info for ssl-chaincheck

# SSL Chain Check `ssl-chaincheck.sh`

This script provides information about every certificate in an SSL chain, not just the first (as is `openssl` default)

Early versions pulled from various systems where the core idea was tweaked to suit local needs, without any central version control. Timing of these are vague, so I've set them to 1 Apr 2022, which feels roughly accurate, and also humorous.
Original awk core was obtained from an online reference, stackoverflow or similar, but now lost to history.

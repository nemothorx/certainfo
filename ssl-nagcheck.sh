#!/bin/bash

# a suggested commandline to sort by date (most critical last), and grouping services with identical expiry date into per-cert groups
# $0 | grep -A100 CRITICAL: | sort -t'(' -k 2gr,2 | sort -t " " -k3g,3 -s | sed -e 's/   */~/g' | column -t -s~ | cut -c 1-220
# note: the script's internal sorting output has changed since that command, and some of it may not be needed
# indeed, this simpler version may be enough:
# $0 | grep -A100 ^CRITICAL | grep -v ^CRITICAL
# TODO: fold more of these output tweakings into the script itself

case "$1" in
    -h|--help)
        echo "
# ssl-nagcheck.sh is a SSL cert check script. Exit code is nagios compatible.

It will search for a config files in:
  - \$HOME/etc/ssl-nagcheck.cfg 
  - \$PWD (this takes priority)

Config can just be a list of hostnames. Optionally also:
  - specify port
  - specify URI path
  - specity content to test for

See config that should have accompanied this script for more details/examples

Any port can be specified. If none specified, defaults to 443

All ports will be connected as SSL with the following exceptions
  - 25/587 = starttls smtp
  - 110 = starttls pop3
  - 143 = starttls imap
  - 80 = no TLS/SSL. Content check only. 

Content checks assume http(s) for all ports except the following:
  - 25/465/587 = smtp banner
  - 110/995 = pop3 banner
  - 143/993 = imap banner
"
        exit 0
        ;;
esac



wdays=35        # days under which we go warning
cdays=14        # days under which we go critical
                    # there is also a hardcoded "SUPER-CRITICAL at 1 day. Its would still be a nagios "CRITICAL"

# curl options I want to use globally
curlopts="-s -k --connect-timeout 2 -m 5 -w \n\n%{response_code}"

# config file...
# if there is one in ~/etc/ ...then use that
[ -e "$HOME/etc/ssl-nagcheck.cfg" ] && cfgfile="$HOME/etc/ssl-nagcheck.cfg"
# if there is one in PWD, it takes precedent
[ -e "ssl-nagcheck.cfg" ] && cfgfile="ssl-nagcheck.cfg"
# (this so the script can be tested against the default config provided in the repo without anyone needing to install anything)

[ -z "$cfgfile" ] && echo "No config file found. Expected ssl-nagcheck.cfg in PWD or \$HOME/etc" && exit 2

# this script uses '~' as an output delimiter, mainly so it can be run from the commandline as 
# $0 | column -t -s~
 
if [ -t ] ; then
    # set some colours for terminal pretty
    grn=$(tput setaf 10)    # green for OK
    ylw=$(tput setaf 11)    # yellow for warning
    red=$(tput setaf 9)     # red for critical
    mve=$(tput setaf 13)    # mauve for unknown
    rev=$(tput rev)         # reverse video
    rst=$(tput sgr0)        # reset
fi

do_termcol() {
    if [ -t ] ; then
        # one sed to add '~' for manual columnnation, 
        # ...then the column and sorting
        # and a second sed for adding colour at the end
        # (makes debugging easier, and colours before column can be weird)
        cat /dev/stdin | sed -e "s/DNS:/~DNS:/g ; s/EXPIRY:/~EXP:/g" | column -t -s~ | sort -t'(' -k2rn | sed -e "s/OK/${grn}OK${rst}/g ; s/WARNING/${ylw}WARNING${rst}/g ; s/ CRITICAL/ ${red}CRITICAL${rst}/g ; s/UNKNOWN/${mve}UNKNOWN${rst}/g ; s/SUPER-CRITICAL/${red}${rev}SUPER-CRITICAL${rst}/g"
    else
        cat /dev/stdin
    fi
}

# this function does the heavy lifting
do_analysis() {
    expstatus=UNKNOWN
    namestatus=UNKNOWN
    while read line ; do
        case $line in
            Not*)   # Not After:
                expdate=${line#*:}
                expdate=$(date -I -d "$expdate") # brevity: ISO 8601 date and ignore time
                now_t=$(date +%s)
                expdate_t=$(date +%s -d "$expdate")
                ttl=$(($expdate_t-$now_t))
                if [ $ttl -ge $(($wdays*86400)) ] ; then
                    expstatus=OK
                else
                    if [ $ttl -lt $(($cdays*86400)) ] ; then
                        if [ $ttl -lt 86400 ] ; then
                            expstatus=SUPER-CRITICAL
                        else
                            expstatus=CRITICAL
                        fi
                    else
                        expstatus=WARNING
                    fi
                fi
                ;;
# the Subject check is removed, on the basis that in the 2020s, the Subject domain is actively *ignored* by browsers, and only SAN entries are considered for name validity
#            Subject:*)  # tag the subject name into dcheck (DNS check list)
#                dcheck="$dcheck,SUBDNS:${line##*=}"
#                dsubj="${line##*=}"
#                ;;
            DNS*)   # tag the san name into the dlist
                dcheck="$dcheck,$(echo $line | grep DNS | sed -e 's/DNS:/SANDNS:/g ; s/ //g')"
                ;;
            serial=*)
                stmp0=${line#*=}
                stmp0cnt=${#stmp0}
                stmp0skip=$((stmp0cnt-3))
                stmp1=${stmp0:0:3}
                stmp2=${stmp0:$stmp0skip:100}
                serial="${stmp1}[$stmp0skip]${stmp2}"
                ;;
            *)
                echo "uh??? $line"
                ;;
        esac
    done < <(cat /dev/stdin)
    echo -n "S/N: $serial"
    case $expstatus in
        *CRITICAL*) echo -n "EXPIRY: $expstatus ($((ttl/86400)) days [$expdate]) " ;;
        *)          echo -n "EXPIRY: $expstatus ($((ttl/86400)) days to renewal) "          ;;
    esac
    while read dom ; do
# TODO: this only matches *.example.com to foo.example.com but not to subdomains (bar.foo.example.com)
#       ...should it?
#       ...and should *.example.com match just "example.com"?
        # strip the san tags for the comparison
        if ( [ "$host" == "${dom#*:}" ] || [ "*.${host#*.}" == "${dom#*:}" ] ) ; then
            # tag the status with san when it matches
            namestatus="OK ${dom%:*}"
            break
        fi
    done < <(echo "$dcheck" | tr "," "\n" | grep . | sort -r | uniq )
    sancnt=$(echo "$dcheck" | tr "," "\n" | grep -c SANDNS)
    case $namestatus in
        # use the status tag to set the appropriate message
#        "OK SUBDNS"*) echo -n "DNS: OK ($host matches Subject: ${dom#*:})" ;;
        "OK SANDNS"*) echo -n "DNS: OK ($host in SAN: ${dom#*:})" ;;
        *) echo -n "DNS: $namestatus ($host NOT in SAN [$sancnt entries])" ;;
    esac
}


########################################### MAIN, effectively

filter=${1:-.}
[ -t ] && echo "Terminal detected. Verbose output. Filtering by $filter"
while read host ports uripath content ; do
    origcontent=$content # make a copy of content, since if we're checking multiple ports AND expect custom error codes, then we alter the value of $content within the next loop. So within the next loop we need to reset it each time
    while read port ; do
        content=$origcontent    # reset $content as per above reasoning
        case $port in
            25) opensslopts="-starttls smtp" ;;
            110) opensslopts="-starttls pop3" ;;
            143) opensslopts="-starttls imap" ;;
            587) opensslopts="-starttls smtp" ;;
            *)
                [ -z "$port" ] && port=443
                opensslopts="" ;;
        esac
# todo: should check dates on the whole chain
        # second round of doing things by port, this time 80 vs all others
        case $port in
            80) rsltmp="S/N: N/AEXPIRY: N/ADNS: N/A" ;;
            *)
                rsltmp=$(timeout 25 openssl s_client -connect $host:$port -servername $host $opensslopts -showcerts </dev/null 2>/dev/null | openssl x509 -noout -text -serial -certopt no_header,no_version,no_serial,no_signame,no_issuer,no_pubkey,no_sigdump -noout 2>/dev/null | grep -E 'Not After :|DNS:|serial=' | do_analysis)
                ;;
        esac
        # TODO: this should handle non-443 ports better (check for smtp/imap/etc banner?)
        if [ -n "$content" ] ; then
            case $port in
                25|587) checkout=$(curl $curlopts -D - -tls smtp://$host:$port/ -X quit) ;;
                110)    checkout=$(curl $curlopts -D - -tls pop3://$host:$port/ -X quit) ;;
                143)    checkout=$(curl $curlopts -D - -tls imap://$host:$port/ -X logout) ;;
                465)    checkout=$(curl $curlopts -D - smtps://$host:$port/ -X quit) ;;
                993)    checkout=$(curl $curlopts -D - imaps://$host:$port/ -X logout) ;;
                995)    checkout=$(curl $curlopts -D - pop3s://$host:$port/ -X quit) ;;
                80)     checkout=$(curl $curlopts -D - http://$host:$port$uripath) ;;
                *)
                    # note: the slash expected between port and uripath...
                    # ...is in the uripath field.
                    # ...because most will be "/" and the cfg needs a value in that field position
                    # ...and I can't have it in both because some embedded servers barf with an error on a double slash, ie, https://$host:$port//$uripath

                    checkout=$(curl $curlopts -D - -L https://$host:$port$uripath) ;;
            esac
            # TODO: we should detect if the curl timed out (exit code 28) and return... unknown? warning? critical?
            # reviewing content: find response code first. 
            responsecode=$(echo "$checkout" | tail -n 1)
            # check if we handle it - we can specify a target response code in the firts : seperated sub-field of the target content check
            if [ "${responsecode}" == "${content%%:*}" ] ; then
                # if it passes, rewrite response code and checkout strings for the next check
                responsecode=200
                content=${content#*:}
            fi

            case $responsecode in 
                # success = 2xx for https and smtp success, and "000" for imap/pop 
                2*|000)
                    echo "$checkout" | grep -q "$content" && contmp="DATA: OK" || contmp="DATA: CRITICAL (string not found)"
                    ;;
                *)
                    # any other response code we treat as an error
                    contmp="DATA: CRITICAL ($responsecode)"
                    # TODO: it might be nice to better indicate in the output which path this was 404'ing on, since we may be checking multiple and currently do not distinguish
                    # ...however, not solving that now, since content checking is already a stretch feature to this script
                    ;;
            esac
        else
            contmp="DATA: N/A"
        fi
        [ -t ] && echo "Checking $host:$port ~ $rsltmp ~ $contmp" | do_termcol 
        rslt="$rslt
$host:$port ~ $rsltmp ~ $contmp"
    done < <(echo "$ports" | tr "," "\n" )
done < <(cat $cfgfile | grep $filter | sed -e 's/#.*//g' | grep -v '^\s*$')

[ -t ] && echo ""

rsltfinal=$(echo "$rslt" | grep .)

# final summarise
count=$(echo "$rsltfinal" | wc -l)
critcount=$(echo "$rsltfinal" | grep -c "CRITICAL")
warncount=$(echo "$rsltfinal" | grep -v "CRITICAL" | grep -c "WARNING")
unkcount=$(echo "$rsltfinal" | grep -v "CRITICAL" | grep -v "WARNING" | grep -c "UNKNOWN")
echo "$rsltfinal" | grep -q CRITICAL && echo "CRITICAL: Performed $count checks. Issues: CRIT:$critcount,WARN:$warncount,UNK:$unkcount" && echo "$rsltfinal" | grep -E 'CRITICAL|WARNING|UNKNOWN' | do_termcol && exit 2
echo "$rsltfinal" | grep -q WARNING && echo "WARNING: Performed $count SSL checks:: WARN:$warncount,UNK:$unkcount issues:" && echo "$rsltfinal" | grep -E 'CRITICAL|WARNING|UNKNOWN' | do_termcol && exit 1
echo "$rsltfinal" | grep -q UNKNOWN && echo "UNKNOWN: Performed $count SSL checks:: UNK:$unkcount issues:" && echo "$rsltfinal" | grep -E 'CRITICAL|WARNING|UNKNOWN' | do_termcol && exit 3

echo "OK: Performed $count SSL checks and All OK.
$rsltfinal" | do_termcol && exit 0

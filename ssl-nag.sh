#!/bin/bash

wdays=28    # days under which we go warning
cdays=14    # days under which we go critical
                # there is also a hardcoded "SUPER-CRITICAL at 1 day. Its still a nagios "CRITICAL"

cfgfile=ssl-nag.cfg

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
        # one sed to add '~' for manual columnnation, and a second for adding colour. This makes tweaking/debugging the two easier
        cat /dev/stdin | sed -e "s/DNS:/~DNS:/g ; s/EXPIRY:/~EXPIRY:/g" | sed -e "s/OK/${grn}OK${rst}/g ; s/WARNING/${ylw}WARNING${rst}/g ; s/ CRITICAL/ ${red}CRITICAL${rst}/g ; s/UNKNOWN/${mve}UNKNOWN${rst}/g ; s/SUPER-CRITICAL/${red}${rev}SUPER-CRITICAL${rst}/g" | column -t -s~
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
                expdate=$(echo $expdate)    # this removes leading/trailing spaces (and collapses any internal)
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
# Subject checking removed since in the 2020s, only SAN is considered for validity (a TIL in 2024)
#            Subject:*)  # tag the subject name into dcheck (DNS check list)
#                dcheck="$dcheck,SUBDNS:${line##*=}"
#                dsubj="${line##*=}"
#                ;;
            DNS*)   # tag the san name into the dlist
                dcheck="$dcheck,$(echo $line | grep DNS | sed -e 's/DNS:/SANDNS:/g ; s/ //g')"
                ;;
            *)
                echo "uh??? $line"
                ;;
        esac
    done < <(cat /dev/stdin)
    case $expstatus in
        *CRITICAL*) echo -n "EXPIRY: $expstatus ($((ttl/86400)) days to renewal [$expdate]) " ;;
        *)          echo -n "EXPIRY: $expstatus ($((ttl/86400)) days to renewal) "          ;;
    esac
    while read dom ; do
# TODO: this only matches *.example.com to foo.example.com but not to subdomains (bar.foo.example.com)
#       ...should it?
#       ...and should *.example.com match just "example.com"?
        # strip the subject/san tags for the comparison
        if ( [ "$host" == "${dom#*:}" ] || [ "*.${host#*.}" == "${dom#*:}" ] ) ; then
            # tag the status with SAN when it matches
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


#### main, effectively
filter=${1:-.}
[ -t ] && echo "Terminal detected. Verbose output. Filtering by $filter"
while read host ports path content ; do
    while read port ; do
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
        rsltmp=$(timeout 25 openssl s_client -connect $host:$port -servername $host $opensslopts -showcerts </dev/null 2>/dev/null | openssl x509 -noout -text -certopt no_header,no_version,no_serial,no_signame,no_issuer,no_pubkey,no_sigdump -noout 2>/dev/null | grep -E 'Not After :|DNS:' | do_analysis)
        [ -t ] && echo "Checking $host:$port ~ $rsltmp" | do_termcol
        rslt="$rslt
$host:$port ~ $rsltmp"
    done < <(echo "$ports" | tr "," "\n" )
done < <(cat $cfgfile | grep $filter | grep -v '#')

[ -t ] && echo ""

rsltfinal=$(echo "$rslt" | grep .)

# final bit
count=$(echo "$rsltfinal" | wc -l)
critcount=$(echo "$rsltfinal" | grep -c "CRITICAL")
warncount=$(echo "$rsltfinal" | grep -v "CRITICAL" | grep -c "WARNING")
unkcount=$(echo "$rsltfinal" | grep -v "CRITICAL" | grep -v "WARNING" | grep -c "UNKNOWN")
echo "$rsltfinal" | grep -q CRITICAL && echo "CRITICAL: Performed $count SSL checks:: CRIT:$critcount,WARN:$warncount,UNK:$unkcount issues:" && echo "$rsltfinal" | grep -E 'CRITICAL|WARNING|UNKNOWN' | do_termcol && exit 2
echo "$rsltfinal" | grep -q WARNING && echo "WARNING: Performed $count SSL checks:: WARN:$warncount,UNK:$unkcount issues:" && echo "$rsltfinal" | grep -E 'CRITICAL|WARNING|UNKNOWN' | do_termcol && exit 1
echo "$rsltfinal" | grep -q UNKNOWN && echo "UNKNOWN: Performed $count SSL checks:: UNK:$unkcount issues:" && echo "$rsltfinal" | grep -E 'CRITICAL|WARNING|UNKNOWN' | do_termcol && exit 3

echo "OK: Performed $count SSL checks and All OK.
$rsltfinal" | do_termcol && exit 0

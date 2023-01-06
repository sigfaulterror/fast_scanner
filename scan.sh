#!/bin/bash
set -e

SUBDOMAIN_WORDLIST_PATH=""
TARGET=""
##########################################
##   Read and check the first argument  ##
##########################################
if [ $# -ge 2 ]; then
    # check if the first argument passed to the script is a valid domain name
    if [[ "$1" =~ ^([a-zA-Z0-9][a-zA-Z0-9-]*\.)+[a-zA-Z]{2,}$ ]]; then
        TARGET="$1"
    else
        echo "The passed argument "$1" is not a valid domain name."
        exit 1
    fi
    if [ -f "$2" ]; then
        SUBDOMAIN_WORDLIST_PATH="$2"
    else
        # The variable is either not set or does not point to a valid file path
        echo "The passed argument "$2" is not a valid file path."
        exit 1
    fi
else
    # No arguments were passed to the script
    echo -e "Please give the target domain and a valid word list as arguments to the script:\n\t./scan.sh example.com /usr/share/wordlist/subdomains.txt"
    exit 1
fi
#Get the absolute path of the massdns utility directory
MASSDNS_PATH=`dirname $(dirname "$(readlink -f $(which massdns))")`

#############################
##   Scanning the target   ##
#############################

Target=$1
dig +short NS  $TARGET|xargs dig +short >dns_resolvers
echo "$MASSDNS_PATH/scripts/subbrute.py $SUBDOMAIN_WORDLIST_PATH $TARGET |  massdns -r $PWD/dns_resolvers -t A -o S -w massdns_result.txt"

"$MASSDNS_PATH/scripts/subbrute.py" "$SUBDOMAIN_WORDLIST_PATH" "$TARGET" |  massdns -r "$PWD/dns_resolvers" -t A -o S -w massdns_result.txt
cat massdns_result.txt |cut -f 1 -d ' '|grep -Po ".*$TARGET"|sort -u > massdns_found_subdomains.txt
echo "[!] amass enum -d $TARGET -dir amass_result -nf massdns_found_subdomains.txt"
amass enum -d "$TARGET" -dir amass_result -nf massdns_found_subdomains.txt

#############################
##   Cleaning temp files   ##
#############################

rm massdns_found_subdomains dns_resolvers


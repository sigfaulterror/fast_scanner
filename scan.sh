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
##   Preparing resolvers   ##
#############################

function resolve_subdomain {
    subdomain=$1
    ns_records=$(dig NS $subdomain +short)
    if [ -z "$ns_records" ]; then
        subdomain=$(echo $subdomain | cut -d'.' -f2-)
        if [ -z "$subdomain" ]; then
            echo "Reached the top-level domain, no resolution found."
            exit 1
        else
            resolve_subdomain $subdomain
        fi
    else
        echo "$ns_records"
    fi
}

function create_resolver {
    resolvers=($(resolve_subdomain $TARGET))
    results=()

    for item in "${resolvers[@]}"; do
        # Check if the value is an IPv4 or IPv6 address
        if [[ $item =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ || $item =~ ^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$ ]]; then
            results+=("$item")
        else
            # If not, perform dig +short and store the result in the results array
            dns=($(dig +short $item))
            for ip in "${dns[@]}"; do
                results+=("$ip")
            done
        fi
    done
    rm -f $PWD/dns_resolvers
    for item in "${results[@]}"; do
        echo $item >>$PWD/dns_resolvers 
    done

}

create_resolver
#############################
##   Scanning the target   ##
#############################

echo "$MASSDNS_PATH/scripts/subbrute.py $TARGET $SUBDOMAIN_WORDLIST_PATH |  massdns -r $PWD/dns_resolvers -t A -o S -w massdns_result.txt"

"$MASSDNS_PATH/scripts/subbrute.py" "$TARGET"  "$SUBDOMAIN_WORDLIST_PATH" |  massdns -r "$PWD/dns_resolvers" -t A -o S -w massdns_result.txt
cat massdns_result.txt |cut -f 1 -d ' '|grep -Po ".*$TARGET"|sort -u > massdns_found_subdomains.txt
echo "[!] amass enum -d $TARGET -dir amass_result -nf massdns_found_subdomains.txt"
amass enum -d "$TARGET" -dir amass_result -nf massdns_found_subdomains.txt

#############################
##   Cleaning temp files   ##
#############################

rm massdns_found_subdomains.txt dns_resolvers


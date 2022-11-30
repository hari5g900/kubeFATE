#!/bin/bash

## Script start time
START=$(date +%s)

## Total run time
DURRATION=$((60 * 60 * 24))

## Total running time
UPTIME=$(($(date +%s) - $START))

while [[ $UPTIME < $DURRATION ]]; do
    

    ## Update running time
    UPTIME=$(($(date +%s) - $START))


    ## Logic here...
    echo -n "Time remaining: "
    echo $(($DURRATION - $UPTIME))
    echo ",$(date)" >> data.csv
    curl http://192.168.100.1/index.cgi?page=modemStatusData | awk -F'##' '/images/{print "," $15 "," $12}' >> data.csv
    ./librespeed-cli --duration 10 --csv --server 51 | awk -F "," '{print "," $5 "," $6 "," $7 "," $7}' >> data.csv

    ## Sleep for a bit
    sleep 300
done

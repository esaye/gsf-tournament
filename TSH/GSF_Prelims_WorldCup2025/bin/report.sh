#!/bin/sh

for div in $@
do
  echo Main Event Division `echo $div | tr a-z A-Z`
  echo ''
  sed -e 's/; p12.*//' $div.t | tourney.pl
  echo ''
done

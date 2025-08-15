#!/bin/sh

for div in $@
do
  divname=`basename $div .t | tr a-z A-Z`
  echo "#division $divname"
  cat $div
done  > all.t

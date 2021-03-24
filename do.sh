#!/bin/bash
#
# do.sh - checkc for new files and start analyzing them
# 
./sync.sh

ls MON*zip |\
while read FILE; do
  echo $FILE
  BASENAME=`basename -s .zip ${FILE}`
  DIRNAME=${BASENAME}
  echo ${DIRNAME}
  if [[ ! -d $DIRNAME ]]; then
    analyzeFD.sh $FILE
  fi
done
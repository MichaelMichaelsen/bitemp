#!/bin/bash
#
# Run the steps for one given zip file
# ------------------------------------
#
SYNCHCOMMAND=./synch.sh
#
# Validate arguments
#
if [[ ! -e $SYNCHCOMMAND ]]; then
   echo "No synch file ($SYNCHCOMMAND) present in this directory"
   exit
fi
$SYNCHCOMMAND
LASTFILE=`head -1 lftp.log | cut -d" " -f4 | cut -d/ -f4`
#
# Start the analysis process
#
analyzeFD.sh $LASTFILE
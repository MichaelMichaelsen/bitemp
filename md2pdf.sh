#!/bin/bash 
#
# Convert Markdown to pdf
#
MDFILE=$1
#
# Validate arguments
#
if [[ ! -e $MDFILE ]]; then
   echo "No Markdown file name given"
   echo "Usage: md2pdf.sh <mdfile>"
   exit
fi

BASENAME=`basename $MDFILE .md`
pandoc $MDFILE --pdf-engine=xelatex -o ${BASENAME}.pdf

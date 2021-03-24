#!/bin/bash
#
# generatedReport.sh - Generate the testreport
#
#
if [ $# -eq 0 ]
  then
    echo "No arguments supplied"
    echo "Usage"
    echo "   generatedReport.sh <zipfile>"
    echo "where"
    echo "   <zipfile> - input zip file"
fi
FILENAME=$1
FULLCD=`pwd`
REGISTER=`basename ${FULLCD}`

if [[ ! -e ${FILENAME} ]]
 then
  echo "Unknown file ${FILENAME}"
fi

BASENAME=`basename ${FILENAME} .zip`

if [[ ! -d ${BASENAME} ]]; 
then
  echo "${BASENAME} has not been created"
  exit
fi

cd  ${BASENAME}
CSVFILE=${BASENAME}.csv
CSSFILE=${BASENAME}.css
HTMLFILE=${BASENAME}.html
MARKDOWNFILE=${BASENAME}.md
echo " Create the test report"
echo "------------------------------"
testreport.pl --zip=../${FILENAME}

#
# Step 6. Render the report in pdf
#

cat > $CSSFILE <<END
body {
  color: black;
}
table {
  border-collapse: collapse;
  width: 800px;
}
table,
th,
td {
  border: 1px solid black;
}
tr:nth-child(even) {
  background-color: #f2f2f2;
}
th {
  background-color: #4CAF50;
  color: white;
}
END

echo "Step 6. Convert the test report to pdf"
echo "---------------------------------------"
markdown  --stylesheet ${CSSFILE} --title ${BASENAME} ${MARKDOWNFILE} > ${HTMLFILE}
pandoc --pdf-engine=wkhtmltopdf --css=${CSSFILE}  ${HTMLFILE} -o ${BASENAME}.pdf
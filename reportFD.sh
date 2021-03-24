#!/bin/bash
#
# reportFD - Generate the reports
#
# The data analysis must have been done and the directory must exists
#
if [ $# -eq 0 ]
  then
    echo "No arguments supplied"
    echo "Usage"
    echo "   reportFD <zipfile>"
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
CSVFILE=${BASENAME}.csv
CSSFILE=${BASENAME}.css
HTMLFILE=${BASENAME}.html
MARKDOWNFILE=${BASENAME}.md

# Check if the directory already exists
if [[ ! -d ${BASENAME} ]]; then
  mkdir ${BASENAME}
fi
cd  ${BASENAME}
# #
# # Step 1. Create the csv file
# #
# echo "Step 1. Create the csv file"
# echo "---------------------------"
# # Check if the csv file aready exists
# if [[ ! -f ${CSVFILE} ]]; then
#   indexjson.pl --zip=../${FILENAME}
# fi
# #
# # Sort the csv according to uuid and listname
# #
# echo "Step 2. Sort the csv file"
# echo "-------------------------"
# SORTFILE=$RANDOM.tmp
# if [[ -f ${CSVFILE}  ]]; then
#    sort -T. -t, --key=5 --key=1 $CSVFILE > $SORTFILE
#    mv $SORTFILE $CSVFILE
# fi
# #
# # Build the SQLITE database
# #
# echo "Step 3. Building the SQLITE database"
# echo "------------------------------------"
# createdb.sh $BASENAME.db $REGISTER $CSVFILE
# #
# # Step 4. Run the checks
# #
# echo "Step 4. Check consistency in data"
# echo "---------------------------------"
# if [[  -f ${CSVFILE} ]]; then
#   checkbitemp.pl --csv=${CSVFILE}
# fi
#
# Step 5. Create the report
#
echo "Step 5. Create the test report"
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

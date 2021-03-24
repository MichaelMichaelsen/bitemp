# createdb.sh creates the database based on the generated csv file
#
# SYNOPSIS
# ========
#
# createdb.sh <databasename> <tablename> <csvfile>
#
# EXAMPLE
# -------
#
# createdb.sh bbr.db bbr index.csv
#
DATABASE=$1
TABLE=$2
CSV=$3
#
# Validate arguments
#
if [[ -z "$DATABASE" ]]; then
   echo "No Database given"
   echo "Usage: createdb.sh <databasename> <tablename> <csvfile>"
   exit
fi
if [[ -z "$TABLE" ]]; then
   echo "No Table name given"
   echo "Usage: createdb.sh <databasename> <tablename> <csvfile>"
   exit
fi
if [[ ! -e $CSV ]]; then
   echo "No CSV file name given"
   echo "Usage: createdb.sh <databasename> <tablename> <csvfile>"
   exit
fi


sqlite3 -batch $DATABASE<<EOF
CREATE TABLE $TABLE (
                  UUID             CHAR(36) NOT NULL,
                  STARTPOS         INT      NOT NULL,
                  ENDPOS           INT      NOT NULL,
                  ENDLINE          INT      NOT NULL,
                  LISTNAME         CHAR(20),
                  REGTIMEFRA       CHAR(40),
                  REGTIMETIL       CHAR(40) NOT NULL,
                  VIRKTIMEFRA      CHAR(40),
                  VIRKTIMETIL      CHAR(40),
                  STATUS           INT
                );
.print "Sqlite: Start importing $TABLE"
.mode csv
.import $CSV $TABLE
.print "Sqlite: Building index UUID"
CREATE INDEX ${TABLE}_idx ON ${TABLE}(UUID);
.print "Sqlite: Building index LISTNAME"
CREATE INDEX Listname_idx ON ${TABLE}(LISTNAME);
.exit

EOF
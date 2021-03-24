.open bbr.db
CREATE TABLE bbr (
                  UUID             CHAR(36) NOT NULL,
                  STARTPOS         INT      NOT NULL,
                  ENDPOS           INT      NOT NULL,
                  LINENO           INT      NOT NULL,
                  LISTNAME         CHAR(20) NOT NULL
                );

.print "Start importing bbr"
.mode csv
.import ../csv/bbr.csv bbr
.print "Building index"
CREATE INDEX bbr_idx ON bbr(UUID);

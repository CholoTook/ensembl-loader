#! /bin/bash

set -e errexit
set -u nounset

## If Ensembl produced proper MySQL dumps, most of the following would
## be much simpler...

## See: https://www.ensembl.org\
## /info/docs/webcode/mirror/install/ensembl-data.html



## TODO: REMOVE THIS CONFIG SOMEHOW...
MYSQL_HOST="mysql"
MYSQL_PASS="IuraetuxuoN7du8Iethei4phie1aeth2"

## TODO: REMOVE THIS CONFIG SOMEHOW...
ENSEMBL_DIR=/BiO/Data/Ensembl/pub



# This allows the mysql instance to come up before we start trying to
# use it...
mycmd="mysqladmin ping -h '$MYSQL_HOST' &> /dev/null"
until eval "$mycmd"; do
    echo "Waiting for MySQL to come up"
    sleep 2
done



## Note that if you used rsync to download the FTP files, as described
## here: https://www.ensembl.org/info/data/ftp/rsync.html, then the
## 'current_mysql' dir should be a symlink to the current release,
## e.g. current_mysql -> release-103/mysql
cd $ENSEMBL_DIR/current_mysql



shopt -s extglob
function do_checksums {
    echo "Checking files in $PWD using 'CHECKSUMS'"
    # Love that code smell!
    diff -b \
         <(sort CHECKSUMS) \
         <(sum !(CHECKSUMS)|sort)
}



function create_database {
    echo "Creating database '$1'"
    mysqladmin -h "$MYSQL_HOST" -p"$MYSQL_PASS" CREATE "$1" \
        || echo "Database '$1' already exists?"
}



function install_database {
    echo "Installing database '$1'"
    echo "Using SQL from '$2'"
    mysql -h "$MYSQL_HOST" -p"$MYSQL_PASS" "$1" < <(gunzip -c "$2")
}



function populate_database {
    echo "Populating database '$1'"

    ## Note, from the manual: The base name of the text file MUST be
    ## the name of the table that should be used!
    for dumpfile in ./*.txt.gz; do
	if [ "$dumpfile" == "./dna.txt.gz" ]; then
	    echo "Skipping DNA for now..."
	    continue
	fi
        echo "Using data from '$dumpfile'"
        mkfifo "${dumpfile/.gz/}.pipe"
        gunzip -c "$dumpfile" >> "${dumpfile/.gz/}.pipe" &
        mysqlimport -h "$MYSQL_HOST" -p"$MYSQL_PASS" \
           --fields-terminated-by='\t' \
                    --fields-escaped-by=\\ \
                    --local --delete \
                    "$1" "${dumpfile/.gz/}.pipe" \
	    || rm -f "${dumpfile/.gz/}.pipe"
        rm -f "${dumpfile/.gz/}.pipe"
    done
    echo "Done"
}



shopt -s nullglob
for dirname in ./*/; do
    echo "$dirname"

    db_name=$(basename "$dirname")
    echo "$db_name"

    cd "$dirname"
    do_checksums .
    create_database "$db_name"
    install_database "$db_name" "$db_name.sql.gz"
    populate_database "$db_name"
    cd ../
done

echo "Done"

#!/bin/bash
#
# Dump selected databases into a github artifacts encrypted
#

########
# VARS #
########
set -x
MONGO_DEB='https://fastdl.mongodb.org/mongocli/mongocli_1.28.0_linux_x86_64.deb'

### Variables must be defined in github
#MONGO_DATABASES="db1,db2,db3"
#MONGO_USER=""
#MONGO_PASS=""
#MONGO_DB_URL=""
#BACKUPS_PASSWORD=""

### Script variables
ZIP_ROUTE_DEFAULT="dump/"
ZIP_FILENAME_DEFAULT="../mongoatlas_backup.zip"

###############
# PREPARATION #
###############
p_magenta() { echo -e "\033[35m$1\033[0m" ;}
p_green() { echo -e "\033[32m$1\033[0m" ;}
p_red() { echo -e "\033[31m$1\033[0m"; }

function install_mongosh(){
    p_green "install mongosh"
    wget "${MONGO_DEB}"
    sudo apt install ./$(echo ${MONGO_DEB}|rev|cut -d '/' -f1|rev)
}

function install_dependencies(){
    p_green "install dependencies"
    sudo apt install wget jq zip -y
}
function convert_databases_into_array(){
    IFS=',' read -r -a databases <<< "$MONGO_DATABASES"
}

function preparation(){
    p_magenta "preparation to run script"
    install_mongosh
    install_dependencies
    convert_databases_into_array
}


######################
# MONGODB MANAGEMENT #
######################


# @param $1 database URL
# @param $2 database name
# @param $3 mongodb user
# @param $4 mongodb password
# 
function list_all_collections_in_a_db(){
    mongosh \
    mongodb+srv://$1/$2 \
    -u "$3" \
    -p "$4" \
    --eval 'db.runCommand({listCollections: 1.0,nameOnly: true})' \
    --quiet \
    --json=canonical \
    |jq .cursor.firstBatch[].name \
    |cut -d '"' -f2 \
    >collections
}

# @param $1 database URL
# @param $2 database name
# @param $3 mongodb user
# @param $4 mongodb password
# @param $5 mongodb collection
function mongoexport_collection(){
    mongoexport \
    --uri mongodb+srv://$1/$2 \
    --collection $5 \
    -u $3 \
    -p $4 \
    --ssl \
    --type json \
    --out $2_$5.json
}

# @param $1 database URL
# @param $2 database name
# @param $3 mongodb user
# @param $4 mongodb password
# @param $5 mongodb collection

function mongodump_database(){
    p_green "dumping database $2"
    mongodump \
    --uri=mongodb+srv://$1 \
    -d $2 \
    -u $3 \
    -p $4 \
    --ssl \
    -o dump/$(cut -d '.' -f1 <<< $1) \
    --gzip
    -vv
}

# @param $1 database URL
# @env $databases[] array with database name
# @param $2 mongodb user
# @param $3 mongodb password
#
function dump_all_databases(){
    p_magenta "dumping server $(cut -d '.' -f1 <<< $1)"
    if [[ ${#databases[@]} -le 0 ]];then 
        p_red "There is no database selected"
        exit 1
    fi
    for db in "${databases[@]}";do
        mongodump_database $1 $db $2 $3
    done
}

#####################
# GENERATE ARTIFACT #
#####################

# @param $1 password
# @param $2 encrypted file name
# @param $3 route to encrypt
function generate_password_protected_zip(){
    p_magenta "Generating password protected zip"
    zip -e -r -P "$1" "$2" "$3"
}

########
# MAIN #
########
function main(){
    p_magenta "Main execution"
    preparation
    dump_all_databases ${MONGO_DB_URL} ${MONGO_USER} ${MONGO_PASS}
    generate_password_protected_zip "${BACKUPS_PASSWORD}" "${ZIP_FILENAME_DEFAULT}" "${ZIP_ROUTE_DEFAULT}"
}

main

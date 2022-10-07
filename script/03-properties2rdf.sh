#!/bin/bash 

###################################################################
# Script Name   :
# Description   :
# Args          : 
# Author        : Michel Héon PhD
# Institution   : Université du Québec à Montréal
# Copyright     : Université du Québec à Montréal (c) 2022
# Email         : heon.michel@uqam.ca
###################################################################
export LOC_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd -P)"
source $LOC_SCRIPT_DIR/../00-env.sh
source $LOC_SCRIPT_DIR/func_cleanup.sh
PATH=$PATH:$LOC_SCRIPT_DIR
TMP_PROP_FN=$TMPDIR/propFn.txt
export ONTO_FN=""
function extract_vars() {
        QUOTE_VALUE="$(echo $PROPFN_VAL | cut -f 2- -d '=')"
        VALUE=${QUOTE_VALUE//\"/\\\"} # replace " by \" in value
        PROP_FN_KEY=$(echo $PROPFN_VAL | cut -f 1 -d '=')
        PROP_FN=$(echo $PROP_FN_KEY | cut -f 1 -d ':')
        PROP_KEY=$(echo $PROP_FN_KEY | cut -f 2 -d ':')
        BN=$(basename $PROP_FN .properties | tr -s ',' '/')
        REGION=$(basename $BN | cut -f 2- -d '_' | tr -s '_' '-'| sed 's/all-//g')
        NT_FN=$KEY.nt
        PKG=$(echo $BN | cut -f 1 -d '/')
        THEME=$(echo $BN | grep theme | sed  's/.*themes\///g' | cut -f 1 -d '/')
        if [ -n "${THEME}" ]; then predicateValue=$PROP_KEY.$PKG.$THEME; else predicateValue=$PROP_KEY.$PKG; fi
}


function print_values () {
printf "PROPFN_VAL=($PROPFN_VAL) \n \
\t VALUE=($VALUE) \n\
\t PROP_FN_KEY=($PROP_FN_KEY) \n\
\t PROP_FN=($PROP_FN) \n\
\t PROP_KEY=($PROP_KEY) \n\
\t BN=($BN) \n\
\t REGION=($REGION) \n\
\t NT_FN=($NT_FN)\n\
\t $BN\n\t\t PKG=$PKG\n\
\t THEME=($THEME) \n\
\t LOCATION=$ONTO_DATA_TTL/$SUB_REP/${ONTO_FN}.ttl \n\
\t predicateValue=$predicateValue \n"
}

###################################################################
###################################################################
## Build the ontology associated to the key
###################################################################
###################################################################
function build_indv() {
    cat $1 | while read PROPFN_VAL
    do
        extract_vars
        [ "$REGION" = "all" ] && REGION='en-US'
        cat << EOF >> $TMP_ONTO_RESULT
<$BASE_IRI#$predicateValue> <http://www.w3.org/2000/01/rdf-schema#label>  "$VALUE"@$REGION .
<$BASE_IRI#$predicateValue> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2002/07/owl#NamedIndividual> .
<$BASE_IRI#$predicateValue> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <$SEMANTIC_BASE_IRI#PropertyKey> . 
<$BASE_IRI#$predicateValue> <$SEMANTIC_BASE_IRI#hasKey> "$PROP_KEY" .
<$BASE_IRI#$predicateValue> <$SEMANTIC_BASE_IRI#hasPackage> "$PKG" . 
<$BASE_IRI#$predicateValue> <$SEMANTIC_BASE_IRI#hasApp> "$( echo $PKG | cut -d '-' -f 1 )" . 
EOF

#        cat << EOF >> $TMP_ONTO_RESULT_FILE
# <$BASE_IRI#$predicateValue> <$SEMANTIC_BASE_IRI#propertiesUrl> "file://$GIT_HOME/$BN.properties"^^<http://www.w3.org/2001/XMLSchema#anyURI> . 
# EOF

        if [ -n "${THEME}" ]; then 
        cat << EOF >> $TMP_ONTO_RESULT
<$BASE_IRI#$predicateValue> <$SEMANTIC_BASE_IRI#hasTheme> "$THEME" . 
EOF
        fi
    done
}


function process_extraction() {
    KEY=$1
    cd $PROPERTIES_DATA
    SUB_REP="${KEY:0:1}"
    grep "^${KEY}=" * > $TMP_PROP_FN 
    ONTO_FN=${KEY}
    echo "($LOOP_CTR/$NBR_LINE) Processing for key = '$KEY',  ontologies: '$ONTO_FN' "
    export TMP_ONTO_RESULT=$TMPDIR/$ONTO_FN.nt
    touch $TMPDIR/$ONTO_FN.nt
    build_indv $TMP_PROP_FN
    process_ftl
    cat $TMP_ONTO_RESULT | sort | uniq | grep -Ev "^$" > $ONTO_DATA/$SUB_REP/$ONTO_FN.nt
    func_nt2ttl.sh < $ONTO_DATA/$SUB_REP/$ONTO_FN.nt > $ONTO_DATA_TTL/$SUB_REP/$ONTO_FN.ttl
    echo "  Done [$KEY] !"

}
process_ftl (){
    cd $GIT_HOME
    for PRODUCTS in "${PRODUCTS_LIST[@]}";  do
         for FTL_FILE in $(find ./$PRODUCTS -name '*.ftl' -path '*main/webapp/*' -exec grep -l -w "$KEY" {} \;); do
         PKG=$PRODUCTS
         THEME=$(echo $FTL_FILE | grep theme | sed  's/.*themes\///g' | cut -f 1 -d '/')
         if [ -n "${THEME}" ]; then predicateValue=$KEY.$PRODUCTS.$THEME; else predicateValue=$KEY.$PRODUCTS; fi
         cat << EOF >> $TMP_ONTO_RESULT
<$BASE_IRI#$predicateValue> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.w3.org/2002/07/owl#NamedIndividual> .
<$BASE_IRI#$predicateValue> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <$SEMANTIC_BASE_IRI#PropertyKey> . 
<$BASE_IRI#$predicateValue> <$SEMANTIC_BASE_IRI#hasKey> "$KEY" .
<$BASE_IRI#$predicateValue> <$SEMANTIC_BASE_IRI#ftlUrl> "file://SRC_HOME${FTL_FILE#.}"^^<http://www.w3.org/2001/XMLSchema#anyURI> . 
<$BASE_IRI#$predicateValue> <$SEMANTIC_BASE_IRI#hasTheme> "$THEME" . 
<$BASE_IRI#$predicateValue> <$SEMANTIC_BASE_IRI#hasPackage> "$PKG" .
<$BASE_IRI#$predicateValue> <$SEMANTIC_BASE_IRI#hasApp> "$( echo $PKG | cut -d '-' -f 1 )" . 
EOF
        done
    done
}

###################################################################
###################################################################
## Main loop: extract the key list
###################################################################
###################################################################
NBR_LINE=$(cat $LIST_OF_KEYS_FN | wc -l )
for _KEY in $(cat $LIST_OF_KEYS_FN)
do
    ((LOOP_CTR=LOOP_CTR+1))
#    KEY=create_new
    process_extraction $_KEY &
    ((j=j+1))
    if [ $j = "15" ]
    then
        wait; ((j=0)) ;  echo "################ New cycle"
    else
        sleep .1
    fi
done
wait 
echo "  Done !"
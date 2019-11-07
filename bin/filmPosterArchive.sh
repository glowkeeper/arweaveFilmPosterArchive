#!/bin/bash

usage ()
{

    echo "usage: $0 -k | --key YOUR_TMDB_API_KEY [-p | --prude] [-m | --movie-only]"

}

testHooverD ()
{
  PORT=1908
  if [ -z "$(lsof -t -i:${PORT})" ]
  then
    echo "error: ensure hooverd is running on port ${PORT}"
    exit 1
  fi
}

getImages ()
{

  let COUNTER=1
  while [ ${COUNTER} -le ${NUM_PAGES} ];
  do

    PAGE="&page=${COUNTER}"
    URL="${BASE_URL}${PAGE}"
    TMP_COUNTER_FILE="/tmp/${COUNTER}_${TMP_FILENAME}"
    curl -s ${URL} > ${TMP_COUNTER_FILE}

    for POSTER in `jq '.results | .[].poster_path' ${TMP_COUNTER_FILE}`
    do

      if [ $POSTER != "null" ]
      then

        THIS_POSTER=$(echo $POSTER | sed 's/"//g')
        THIS_POSTER_URL="${BASE_TMDB_IMAGE_URL}${THIS_POSTER}"
        curl -s ${THIS_POSTER_URL} > /tmp/${THIS_POSTER}

      fi

    done

    rm ${TMP_COUNTER_FILE}

    let COUNTER++

  done

}

testHooverD

#API_KEY="?api_key=b6242bd7de50b9dc95a670a56759bf57"
API_KEY=""

BASE_TMDB_IMAGE_URL="https://image.tmdb.org/t/p/original"
BASE_TMDB_DISCOVER_URL="https://api.themoviedb.org/3/discover/movie"

DATE_YESTERDAY=$(date --date yesterday '+%Y-%m-%d')
DATE_TODAY=$(date --date today '+%Y-%m-%d')
RELEASE_YESTERDAY="&primary_release_date.gte=${DATE_YESTERDAY}"
RELEASE_TODAY="&primary_release_date.lte=${DATE_TODAY}"

ADULT="&include_adult=true"
MOVIE="&include_video=true"

while [ $# -gt 0 ]
do

  case "$1" in

      "-k" | "--key" )  API_KEY="?api_key=$2" ; shift 2;;
      "-p" | "--prude" )  ADULT="&include_adult=false" ; shift ;;
      "-m" | "--movie-only" )  MOVIE="&include_video=false" ; shift ;;
      * ) usage ; exit 1 ;;

  esac

done

if [ -z ${API_KEY} ]
then

  usage
  exit 1

fi

BASE_URL="${BASE_TMDB_DISCOVER_URL}${API_KEY}${MOVIE}${ADULT}${RELEASE_YESTERDAY}${RELEASE_TODAY}"

TMP_FILENAME="tmdb.json"
TMP_FILE="/tmp/${TMP_FILENAME}"

curl -s ${BASE_URL} > ${TMP_FILE}
NUM_PAGES=$(jq '.total_pages' ${TMP_FILE})

getImages

rm ${TMP_FILE}
exit 0

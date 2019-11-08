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

postToArweave ()
{

  local FILE="$1"
  curl -s -k -X POST -F "image=@${FILE}" http://localhost:1908/raw

}

createHTML ()
{

  cp "${HTML_HEADER}" "${OUTPUT_FILENAME}"
  cat "${HTML_TEMPLATE}" >> "${OUTPUT_FILENAME}"
  DATE="$(date)"
  echo "<h1>Film Releses for ${DATE}</h1>" >> "${OUTPUT_FILENAME}"

}

createRow ()
{
  POSTER="$1"
  TITLE="$2"
  OVERVIEW="$3"

  echo "<tr>" >> "${OUTPUT_FILENAME}"
  echo "<th colspan=2>${TITLE}</th>" >> "${OUTPUT_FILENAME}"
  echo "</tr>" >> "${OUTPUT_FILENAME}"
  echo "<tr>" >> "${OUTPUT_FILENAME}"

  if [ $POSTER != "null" ]
  then

    THIS_POSTER=$(echo $POSTER | sed 's/"//g' | sed 's/^\///')
    THIS_POSTER_URL="${BASE_TMDB_IMAGE_URL}/${THIS_POSTER}"
    TEMP_POSTER="${TMP_DIR}/${THIS_POSTER}"
    curl -s ${THIS_POSTER_URL} > ${TEMP_POSTER}

    echo "<td class=\"img\"><img src=\"${THIS_POSTER}\" alt=\"${TITLE}\">" >> "${OUTPUT_FILENAME}"
    echo "<td class=\"overview\">${OVERVIEW}</th>" >> "${OUTPUT_FILENAME}"

  else

    echo "<td colspan=2>${OVERVIEW}</th>" >> "${OUTPUT_FILENAME}"

  fi

  echo "</tr>" >> "${OUTPUT_FILENAME}"

}

appendFooter ()
{

  cat "${HTML_FOOTER}" >> "${OUTPUT_FILENAME}"

}

getNumPages ()
{

  curl -s ${BASE_URL} > ${TMP_FILE}
  echo "$(jq '.total_pages' ${TMP_FILE})"

}

getFilms ()
{

  local NUM_PAGES=$1
  let COUNTER=1
  while [ ${COUNTER} -le ${NUM_PAGES} ];
  do

    PAGE="&page=${COUNTER}"
    URL="${BASE_URL}${PAGE}"
    TMP_COUNTER_FILE="${TMP_DIR}/${COUNTER}_${TMP_FILENAME}"
    curl -s ${URL} > ${TMP_COUNTER_FILE}

    for INDEX in $(jq '.results | keys | .[]' ${TMP_COUNTER_FILE})
    do

      POSTER=$(jq -r ".results[${INDEX}].poster_path" ${TMP_COUNTER_FILE} | sed 's/"//g')
      TITLE=$(jq -r ".results[${INDEX}].title" ${TMP_COUNTER_FILE})
      OVERVIEW=$(jq -r ".results[${INDEX}].overview" ${TMP_COUNTER_FILE})

      createRow "${POSTER}" "${TITLE}"  "${OVERVIEW}"

      if [ $POSTER != "null" ]
      then

        THIS_POSTER=$(echo $POSTER | sed 's/"//g')
        THIS_POSTER_URL="${BASE_TMDB_IMAGE_URL}${THIS_POSTER}"
        TEMP_POSTER="${TMP_DIR}/${THIS_POSTER}"
        curl -s ${THIS_POSTER_URL} > ${TEMP_POSTER}
        #postToArweave ${TEMP_POSTER}
        #rm ${TEMP_POSTER}
      fi

    done

    #rm ${TMP_COUNTER_FILE}

    let COUNTER++

  done

}

testHooverD

TMP_DIR="/tmp/filmArchiver$$"
mkdir "${TMP_DIR}"

HTML_HEADER="$(pwd)/../templates/header.html"
HTML_TEMPLATE="$(pwd)/../templates/body.html"
HTML_FOOTER="$(pwd)/../templates/footer.html"
OUTPUT_FILENAME="${TMP_DIR}/filmArchiver.html"

createHTML

#API_KEY="?api_key=b6242bd7de50b9dc95a670a56759bf57"
API_KEY=""

BASE_TMDB_IMAGE_URL="https://image.tmdb.org/t/p/w500"
BASE_TMDB_DISCOVER_URL="https://api.themoviedb.org/3/discover/movie"

DATE_TODAY=$(date --date today '+%Y-%m-%d')
SORT="&sort_by=popularity.desc"
RELEASE_FIRST="&primary_release_date.gte=${DATE_TODAY}"
RELEASE_LAST="&primary_release_date.lte=${DATE_TODAY}"

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

BASE_URL="${BASE_TMDB_DISCOVER_URL}${API_KEY}${MOVIE}${ADULT}${SORT}${RELEASE_FIRST}${RELEASE_LAST}"
TMP_FILENAME="tmdb.json"
TMP_FILE="${TMP_DIR}/${TMP_FILENAME}"

NUM_PAGES=$(getNumPages)
getFilms $NUM_PAGES

appendFooter

#rm ${TMP_FILE}
exit 0

#!/usr/bin/env bash

set -Eeo pipefail

dependencies=(curl gawk gzip)
for program in "${dependencies[@]}"; do
    command -v "$program" >/dev/null 2>&1 || {
        echo >&2 "Couldn't find dependency: $program. Aborting."
        exit 1
    }
done

AWK=$(command -v gawk)
CURL=$(command -v curl)
GZIP=$(command -v gzip)

if [[ "${RUNNING_IN_DOCKER}" ]]; then
    source "/app/imdb_exporter.conf"
else
    #shellcheck source=/dev/null
    source "$CREDENTIALS_DIRECTORY/creds"
fi

[[ -z "${INFLUXDB_HOST}" ]] && echo >&2 "INFLUXDB_HOST is empty. Aborting" && exit 1
[[ -z "${INFLUXDB_API_TOKEN}" ]] && echo >&2 "INFLUXDB_API_TOKEN is empty. Aborting" && exit 1
[[ -z "${ORG}" ]] && echo >&2 "ORG is empty. Aborting" && exit 1
[[ -z "${BUCKET}" ]] && echo >&2 "BUCKET is empty. Aborting" && exit 1
[[ -z "${IMDB_WATCHLIST_ID}" ]] && echo >&2 "IMDB_WATCHLIST_ID is empty. Aborting" && exit 1

INFLUXDB_URL="https://$INFLUXDB_HOST/api/v2/write?precision=s&org=$ORG&bucket=$BUCKET"
IMDB_URL="https://www.imdb.com/list/${IMDB_WATCHLIST_ID}/export"

imdb_csv=$($CURL --silent --fail --show-error --compressed "$IMDB_URL")

imdb_stats=$(
    echo "$imdb_csv" |
        # handle csv with gawk < v5.3
        $AWK --assign FPAT='[^,]*|("([^"]|"")*")' \
            '{
                if (NR > 1)
                printf "imdb_stats,title_type=%s,genres=%s,year=%d position=%d,imdb_id=\"%s\",title=\"%s\",imdb_rating=%.1f,runtime_mins=%d,imdb_votes=%d,release_date=\"%s\",directors=\"%s\" %s\n",
                $8,
                gensub(/[[:space:]]/, "\\\\ ", "g", gensub(/"|,/, "", "g", $12)),
                $11, $1, $2,
                gensub(/"|,/, "", "g", $6),
                $9, $10, $13, $14,
                gensub(/"|,/, "", "g", $15),
                mktime(gensub(/-/, " ", "g", $3)" 0 0 0")
            }'
)

echo "$imdb_stats" | $GZIP |
    $CURL --silent --fail --show-error \
        --request POST "${INFLUXDB_URL}" \
        --header 'Content-Encoding: gzip' \
        --header "Authorization: Token $INFLUXDB_API_TOKEN" \
        --header "Content-Type: text/plain; charset=utf-8" \
        --header "Accept: application/json" \
        --data-binary @-

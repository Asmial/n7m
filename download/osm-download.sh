#!/usr/bin/env bash

for OSM_AREA in $OSM_AREAS;
do
    FILENAME="$OSM_AREA.osm.pbf"

    if [[ -e "$FILENAME.aria2" || ! -e $FILENAME ]]; then
        download-osm $OSM_AREA -o "$OSM_AREA.osm.pbf"
    fi
done

/scripts/download.sh --wiki --grid

curl "$PGHOST:5432" > /dev/null 2>&1

while [[ $? != '52' ]]
do
    echo "Connecting to $PGHOST..."
    sleep 5
    curl "$PGHOST:5432" > /dev/null 2>&1
done

#!/usr/bin/env bash

for OSM_AREA in $OSM_AREAS;
do
    download-osm $OSM_AREA -o "$OSM_AREA.osm.pbf"
done

export NOMINATIM_DATABASE_DSN="pgsql:dbname=$PGDATABASE;host=$PGHOST;user=$PGUSER;password=$PGPASSWORD"


curl "$PGHOST:5432" > /dev/null 2>&1

while [[ $? != '52' ]]
do
    echo "Connecting to $PGHOST..."
    sleep 5
    curl "$PGHOST:5432" > /dev/null 2>&1
done

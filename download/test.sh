#!/usr/bin/env bash

for OSM_AREA in $OSM_AREAS;
do
    if [[ ! -e "$OSM_AREA.osm.pbf" ]]; then
        exit 1
    fi
done

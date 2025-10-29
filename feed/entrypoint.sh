#!/bin/bash

set -e

# Export this for the Nominatim CLI
export NOMINATIM_DATABASE_DSN="pgsql:dbname=$PGDATABASE;host=$PGHOST;user=$PGUSER;password=$PGPASSWORD"
export PROCESSING_UNITS=$(nproc)

function waitForGis() {
  # wait for gis container to reach a ready state
  while ! psql --list > /dev/null 2>&1
  do
    echo "Connecting to $PGHOST..."
    sleep 5
  done
}

function waitForGisDatabase() {
  # wait for gis container to reach a ready state
  while ! psql --list | grep $1 > /dev/null 2>&1
  do
    echo "Waiting for $PGHOST/$1..."
    sleep 10
  done
}

if [ "$1" = 'reset' ]; then
  waitForGis

  # drop nominatim database and user then continue setup
  if psql --command "DROP DATABASE nominatim;"; then
    echo "Database does not exist"
  fi
  if psql --command "DROP USER \"www-data\";"; then
    echo "User does not exist"
  fi
  exit 0
fi

if [ "$1" = 'download' ] || [ "$1" = 'dl' ]; then
  exec ./download.sh "$@"
fi

if [ "$1" = 'setup' ]; then
  waitForGis

  # test to see if our database exists
  # https://stackoverflow.com/questions/14549270/check-if-database-exists-in-postgresql-using-shell
  if psql -lt | cut -d \| -f 1 | grep -qw nominatim; then
    echo "Database already exists"
    exit 0
  else
    echo "Database has not been setup"
  fi

  for OSM_AREA in $OSM_AREAS;
  do
    OSM_FILENAME="$OSM_AREA.osm.pbf"

    OSM_PATH=/data/$OSM_FILENAME

    if [ -s ${OSM_PATH} ]; then
      echo "$OSM_PATH exists."
    else
      echo "Database $OSM_PATH does not exist.  Please specify variable 'OSM_FILENAME'  Exiting."
      exit 1
    fi

  done

  # create required users that the tool checks
  createuser www-data

  echo "Starting Import"
  echo "Number of processing units: $PROCESSING_UNITS"

  for OSM_AREA in $OSM_AREAS;
  do
    OSM_FILENAME="$OSM_AREA.osm.pbf"
    
    OSM_PATH=/data/$OSM_FILENAME

    # time the import so we can compare database configuration
    time nominatim import $NOMINATIM_IMPORT_FLAGS --osm-file /data/$OSM_FILENAME --project-dir /data --threads $PROCESSING_UNITS
    if [ $? != 0 ]; then
      echo "Import failed: $OSM_AREA"
      exit 1
    fi
    echo "Import complete: $OSM_AREA"
  done

  exit 0
fi

if [ "$1" = 'update' ]; then
  # run replication once
  # any scheduling should be done outside this container
  
  # set this if you want to be more aggressive 
  # https://nominatim.org/release-docs/latest/customize/Settings/
  # NOMINATIM_REPLICATION_MAX_DIFF=3000

  waitForGis
  waitForGisDatabase nominatim

  echo "Starting Update"
  echo "Number of processing units: $PROCESSING_UNITS"

  nominatim replication --init

  for OSM_AREA in $OSM_AREAS;
  do
    OSM_FILENAME="$OSM_AREA.osm.pbf"
    
    OSM_PATH=/data/$OSM_FILENAME

    NOMINATIM_REPLICATION_URL=https://download.geofabrik.de/$OSM_AREA-updates

    # time the import so we can compare database configuration
    time nominatim import $NOMINATIM_IMPORT_FLAGS --osm-file /data/$OSM_FILENAME --project-dir /data --threads $PROCESSING_UNITS
    exec nominatim replication --once --threads $PROCESSING_UNITS
  done

fi

if [ "$1" = 'replication' ]; then
  # run replication with any additonal command line options
  waitForGis
  waitForGisDatabase nominatim

  echo "Starting Update"
  echo "Number of processing units: $PROCESSING_UNITS"

  nominatim replication --init
  exec nominatim "$@" --threads $PROCESSING_UNITS
fi

exec "$@"

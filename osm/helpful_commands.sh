# -b bounding box --complete-ways
# osmconvert should be preinstalled
osmconvert texas-latest.osm.pbf -b=-100,25,-90,36.8 --complete-ways -o=texas-subset-latest.osm.pbf
osmconvert california-latest.osm.pbf -b=-124,32,-113.8,39.2 --complete-ways -o=california-subset-latest.osm.pbf

# ogr2ogr: osm.pbf to SQLite
# note that dest comes first, input comes next
ogr2ogr -f "SQLite" -dsco SPATIALITE=YES ../texas.db texas-latest.osm.pbf


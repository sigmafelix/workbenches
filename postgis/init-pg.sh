#!/bin/zsh
PGDATA="$HOME/postgresql/$USER"

if [ ! -d "$PGDATA" ]; then
  mkdir -p "$PGDATA"
fi

pg_ctl -D "$PGDATA" -l $POSTGRESQL_SERVER -w -U "$POSTGRESQL_USER" -P "$POSTGRESQL_PASSWORD" init

createdb -O "$POSTGRESQL_USER" "$POSTGRESQL_DATABASE"


# EOF

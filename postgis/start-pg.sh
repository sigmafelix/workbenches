#! /bin/zsh
# after initialization

postgres &
psql -h /tmp/ $POSTGRES_USER_DBNAME

# EOF

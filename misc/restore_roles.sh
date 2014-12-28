
set -x

HOST='localhost'
PORT=15432
USER='postgres'

DIR=20131011


psql -h "$HOST" -p "$PORT" -U "$USER" -d postgres -f "$DIR/roles.dump"



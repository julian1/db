set -x

DB=mytest
HOST=localhost

psql -h $HOST -U postgres  -c "drop database if exists $DB;"
psql -h $HOST -U postgres  -c "drop role if exists $ROLE;"

psql -h $HOST -U postgres -d $DB -c "create schema blue;"

# create a table and a sequence
psql -h $HOST -U postgres -d $DB -c "create table blue.xxx ( x bigint, y bigint );"
psql -h $HOST -U postgres -d $DB -c "create sequence blue.my_sequence ;"

# test the sequence
psql -h $HOST -U postgres -d $DB -c "select nextval( 'blue.my_sequence' ) ;"
psql -h $HOST -U postgres -d $DB -c "select nextval( 'blue.my_sequence' ) ;"
psql -h $HOST -U postgres -d $DB -c "select nextval( 'blue.my_sequence' ) ;"

#######
# create new schema and move objects

# what happens if it has foreign key relations with a table in old schema ? - perhaps would be ok.
# and move it into different schema

# create a new schema and move the table
psql -h $HOST -U postgres -d $DB -c "create schema red;"
psql -h $HOST -U postgres -d $DB -c "alter table blue.xxx set schema red;"


# move it to another schema
psql -h $HOST -U postgres -d $DB -c "alter sequence blue.my_sequence set schema red;"



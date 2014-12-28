
## Example how it's not necessary to grant 'connect' privileges for a user against a db.
## Here the ability to create a table follows from schema ownership
## It's also possible to do this for default users

DB=harvest

# create two users 'src' and 'target' 
psql -h localhost -U postgres -d $DB -c "
	drop schema if exists x cascade;
	drop role if exists x;

	create user x password 'x';
	create schema x authorization x;
";


psql -h localhost -U x -d $DB -c "

	create table mytable ( id int );

";
	

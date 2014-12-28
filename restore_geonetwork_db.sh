set -x

instance=geonetwork_anz
dump=/vagrant/geonetwork_123.dump

sudo /etc/init.d/tomcat7_$instance stop

sudo -u postgres psql -c "drop database $instance"
sudo -u postgres psql -c "create database $instance"
sudo -u postgres psql -d $instance -c 'create extension postgis schema public '

sudo -u postgres pg_restore -n public $dump -d $instance

read -d '' STRING <<"EOF"

	CREATE FUNCTION exec(text) returns text
	language plpgsql volatile
	AS $$
		BEGIN
		  EXECUTE $1;
		  RETURN $1;
		END;
	$$;
	grant all on function exec(text) to public;

	create function grant_read_on_schema_and_objects( schema text, role text ) returns void
	language plpgsql volatile
	as $$
	  begin
		perform exec(
			'grant usage on schema '||$1||' to '||$2||';'
			'grant select on ALL TABLES IN SCHEMA '||$1||' to '||$2||';'
			'grant select on ALL sequences IN SCHEMA '||$1||' to '||$2||';'
			'grant execute on ALL functions IN SCHEMA '||$1||' to '||$2||';'
	  );
	  end;
	$$;
	grant all on function grant_read_on_schema_and_objects( schema text, role text ) to public;


	-- rename to grant all?
	create function grant_write_on_schema_and_objects( schema text, role text ) returns void
	language plpgsql volatile
	as $$
	  begin
		perform exec(
			'grant all on schema '||$1||' to '||$2||';'
			'grant all on ALL TABLES IN SCHEMA '||$1||' to '||$2||';'
			'grant all on ALL sequences IN SCHEMA '||$1||' to '||$2||';'
			'grant all on ALL functions IN SCHEMA '||$1||' to '||$2||';'
	  );
	  end;
	$$;
	grant all on function grant_write_on_schema_and_objects( schema text, role text ) to public;


	select grant_read_on_schema_and_objects( 'public', 'geonetwork_read_group' ); 
	select grant_write_on_schema_and_objects( 'public', 'geonetwork' ); 
	select grant_write_on_schema_and_objects( 'public', 'geonetwork_write_group' ); 
EOF


sudo -u postgres psql -d $instance -c "$STRING"



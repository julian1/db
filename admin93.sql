-- Usage psql -f create_class_view.sql

-- shows postgres objects(classes) relations, sequences, indexes etc and their owners and permissions
-- psql -c "alter default privileges for role postgres in schema public revoke all on tables from  aaa"

-- we just need to use the array function to exapand the default attributes stored as an array. - then we can write
-- a function to pull off all the default attributes from a schema.


-- have a version() function

-- have relation, schema, and database sizes views,


drop schema if exists admin cascade;
create schema admin;
grant all on schema admin to public;


SET search_path = admin, pg_catalog;


-- versioning
CREATE FUNCTION version() returns float
language plpgsql
AS $f$
  BEGIN
  RETURN ( select 0.1 );
  END;
$f$;
grant all on function version() to public;



-- Incredibly useful function that enables writing ddl functions easily
-- See here, http://stackoverflow.com/questions/1348126/modify-owner-on-all-tables-simultaneously-in-postgresql
-- Examples:
-- psql -c "select admin.exec( 'select 1' )"
-- psql -c "select admin.exec( 'drop function '||fullname) from admin.functions where name = 'myfunc'"

-- psql -c 'create or replace function test1( a int, b int) returns integer as $a$ declare ret int;  begin select $1 + $2 into ret; return ret; end $a$ language plpgsql;'
-- psql -c "select fullname  from admin.functions where schema = 'public' "
-- psql -c "select admin.exec( 'drop function '||fullname) from admin.functions where name = 'test1'"
-- psql -c "select fullname  from admin.functions where schema = 'public' "


-- dropping all views, in a schema.
-- psql -h dbprod.emii.org.au -U jfca -d harvest -c "select admin.exec( 'drop view if exists '||schema||'.'||name||' cascade' ) from admin.objects3 where kind = 'v' and schema = 'reporting' "

-- psql -c "select admin.exec( 'alter table '||schema||'.'||object||' owner to aaa') from admin.objects where kind = 'r' and schema = 'public' "
CREATE FUNCTION exec(text) returns text
language plpgsql volatile
AS $f$
    BEGIN
      EXECUTE $1;
      RETURN $1;
    END;
$f$;
grant all on function exec(text) to public;


-- Same as above but returns the result as an integer
CREATE FUNCTION exec_returning_int(text) returns integer
language plpgsql volatile
AS $f$
  declare
     n integer;
    BEGIN
      EXECUTE $1 into n;
      RETURN n;
    END;
$f$;
grant all on function exec_returning_int(text) to public;



-- view over db objects such as relations, indexes, sequences,
create view objects as
   (
  select 
    n.nspname as schema,
    o.relkind::char(1) as kind,
    o.relname as name,
    o.oid as oid,
    r.rolname as owner,
    o.relacl as acl

    from pg_class o
    left join pg_namespace n on n.oid=o.relnamespace
    left join pg_roles r on r.oid=o.relowner

	union all

     SELECT
    nspname as schema,
	'f'::char(1) as kind,
    proname as name,
    p.oid as oid,
    r.rolname as owner,
    proacl as acl
    -- p.*,
   -- p.oid::regproc||'('||pg_get_function_identity_arguments( p.oid)||')' as fullname,
    
	FROM pg_proc p
    left join pg_namespace n on n.oid=  p.pronamespace
    left join pg_roles r on r.oid=p.proowner

	order by schema, kind, name

  );
grant all on table objects to public;







-- view of objects with expanded acl for ddl actions 
create view objects2 as
SELECT
    n.nspname as schema,
    x.name,
    x.kind,
	x.oid,
    x.privilege_type as privilege,
    u.rolname as grantor,
    u2.rolname as grantee 
FROM
    (
        SELECT
		c.relname as name, --oid::regclass as name,
	    c.relkind as kind ,
	    c.relnamespace as relnamespace,
		c.oid as oid,
		(aclexplode( c.relacl )).*
        FROM
            pg_class c
    ) as x
    left join pg_roles u on x.grantor = u.oid
    left join pg_roles u2 on x.grantee = u2.oid
    left join pg_namespace n on n.oid=x.relnamespace
order by schema, kind, name
;
grant all on table objects2 to public;



-- simplified view of objects without acl
create view objects3 as
  select 
    schema, name, kind, oid, owner
    from objects
  ;
grant all on table objects3 to public;


-- relation counts 
create view counts as
   (
	select 
		schema,
		name, 
		admin.exec_returning_int( 'select count(*) from ' || schema||'.'||name ) as count 
		from admin.objects 
		where kind = 'r' 
		order by schema,name
);

grant all on table counts to public;


-- view over constraints -- need the table
-- conrelid 

create view constraints as
  select 
	n.nspname as schema,
	r.relname as relation,
    c.conname as name
    from pg_constraint c
    left join pg_namespace n on n.oid=c.connamespace
	LEFT JOIN pg_class r ON r.oid = c.conrelid 
	order by schema, relation, name 
  ;
grant all on table constraints to public;


-- psql -d aatams3 -c "select * from pg_constraint  "
-- conname                            | connamespace




-- view over fields
-- taken from
-- http://en.wikibooks.org/wiki/Converting_MySQL_to_PostgreSQL#Language_Constructs

create view fields as
SELECT
		n.nspname as schema,
		c.relname as relation,
		c.relkind as kind,
        a.attname AS field,
--		r.*,
        t.typname || '(' || a.atttypmod || ')' AS Type,
        CASE WHEN a.attnotnull = 't' THEN 'YES' ELSE 'NO' END AS _notnull,
        -- CASE WHEN r.contype = 'p' THEN 'PRI' ELSE '' END AS Key,
--        r.contype as Contype,
        (SELECT pg_catalog.pg_get_expr(d.adbin, d.adrelid)
                FROM
                        pg_catalog.pg_attrdef d
                WHERE
                        d.adrelid = a.attrelid
                        AND d.adnum = a.attnum
                        AND a.atthasdef) AS _default,
--        ''::varchar as Extras,
		pg_get_constraintdef(c2.oid, true) as _constraint
--from pg_attribute a
    -- left join pg_constraint c on c.conrelid = a.attrelid
--		, pg_catalog.obj_description(239533, 8)
		, pg_catalog.col_description( c.oid, a.attnum) as _comment
	

FROM
        pg_class c 
        JOIN pg_attribute a ON a.attrelid = c.oid
        JOIN pg_type t ON a.atttypid = t.oid
        LEFT JOIN pg_catalog.pg_constraint r ON c.oid = r.conrelid 
			AND r.conname = a.attname
		left join pg_namespace n on n.oid=c.relnamespace

	LEFT JOIN pg_constraint c2 ON (c2.conrelid = a.attrelid
	AND (c2.conkey[1] = a.attnum
	OR c2.conkey[2] = a.attnum OR c2.conkey[3] = a.attnum
	OR c2.conkey[4] = a.attnum OR c2.conkey[5] = a.attnum
	OR c2.conkey[6] = a.attnum) OR c2.conkey[7] = a.attnum
	OR c2.conkey[8] = a.attnum)
WHERE
 --       c.relname = 'tablename'
--        AND a.attnum > 0
        a.attnum > 0
--ORDER BY a.attnum
ORDER BY n.nspname, c.relname , a.attnum;

grant all on table fields to public;







-- xmins record the last transaction to write the table. can be used to determine
-- if a table is being actively updated over time.
-- this is pretty costly to run
create view xmins as
select
  schema,
  name,
  admin.exec_returning_int ( 'select max(xmin::text::bigint) from '||schema ||'.'|| name ) as xmin
  from objects 
  where kind = 'r'
;
grant all on table xmins to public;



-- view over functions - includes fully qualified function name, easing construction of ddl actions
create view functions as
  (
     SELECT
    nspname as schema,
    proname as name,
    r.rolname as owner,
    p.oid as oid,
    -- p.*,
    p.oid::regproc||'('||pg_get_function_identity_arguments( p.oid)||')' as fullname,
    proacl as acl
    FROM pg_proc p

    left join pg_namespace n on n.oid=  p.pronamespace
    left join pg_roles r on r.oid=p.proowner
    order by nspname, proname
);
grant all on table functions to public;


-- view over function src
create view functions2 as
  (
  SELECT
    nspname as schema,
    proname as name,
    p.oid::regproc||'('||pg_get_function_identity_arguments( p.oid)||')'||regexp_replace( p.prosrc, '[ \t]+', ' ', 'g') as src
    -- regexp_replace( p.prosrc, '[ \t]+', ' ', 'g')
  FROM pg_proc p
  LEFT JOIN pg_namespace n ON n.oid = p.pronamespace

  order by nspname, proname
);
grant all on table functions2 to public;



-- view of schemas, owners and acl
create view schemas as
  select nspname as schema,
  rolname as owner,
  nspacl as acl
  from pg_namespace s
  left join pg_roles a on a.oid = s.nspowner
  order by nspname
;
grant all on table schemas to public;


-- default acls for objects - eg created with 'alter default privileges'
create view defaults as
  select
    n.nspname as schema,
    d.defaclobjtype as kind,
    d.defaclacl as defaultacl
    from pg_catalog.pg_default_acl d
    left join pg_catalog.pg_namespace n ON n.oid = d.defaclnamespace
;
grant all on table defaults to public;


-- exploded defaults view, that can be used for ddl
-- see discussion here, about how to construct this for different postgres versions
-- http://www.depesz.com/2012/08/19/waiting-for-9-3-implement-sql-standard-lateral-subqueries/
--
-- psql -d harvest -c "select  admin.exec( 'alter default privileges in schema '||schema||' for role '||grantor||' revoke '||privilege||' on tables from '||grantee)  from admin.defaults2 where kind = 'r' and schema = 'dw_aatams' "


create view defaults2 as
SELECT
    n.nspname as schema,
    x.defaclobjtype as kind,
    x.privilege_type as privilege,
    u.rolname as grantor,
    u2.rolname as grantee 
FROM
    (
        SELECT
	    d.defaclobjtype as defaclobjtype,
	    d.defaclnamespace as relnamespace,
		(aclexplode( d.defaclacl )).*
        FROM
	    pg_default_acl d
    ) as x
    left join pg_roles u on x.grantor = u.oid
    left join pg_roles u2 on x.grantee = u2.oid 
    left join pg_namespace n on n.oid= x.relnamespace
;
grant all on table defaults2 to public;


-- role membership
create view membership as
  SELECT
    y.rolname as role,
    x.rolname as parent,
    z.rolname  as grantor
  from pg_auth_members m
    left join pg_roles x on m.roleid = x.oid
    left join pg_roles y on m.member = y.oid
    left join pg_roles z on m.grantor = z.oid
  order by member
;
grant all on table membership to public;


-- role config such as search_path
create view config as
  SELECT
    d.datname as database,
    r.rolname as role,
    s.setconfig as config
    FROM pg_db_role_setting s
    LEFT JOIN pg_roles r ON s.setrole = r.oid
    LEFT JOIN pg_database d ON s.setdatabase = d.oid
;
grant all on table config to public;


-- shows sizes of relations
create view size_relation as
SELECT
  -- nspname || '.' || relname AS "relation",
  nspname as schema,
  relname AS relation,
    pg_size_pretty(pg_relation_size(C.oid)) AS "size"
  FROM pg_class C
  LEFT JOIN pg_namespace N ON (N.oid = C.relnamespace)
--  WHERE nspname NOT IN ('pg_catalog', 'information_schema')
--   ORDER BY pg_relation_size(C.oid) DESC
  ORDER BY schema, pg_relation_size(C.oid) DESC
;
grant all on table size_relation to public;


-- show size of schemas
create view size_schema as
select 
	schema,   
	pg_size_pretty( sum(pg_relation_size( oid )::bigint) ) as size  
	from admin.objects 
	where kind = 'r' 
	group by schema 
;
grant all on table size_schema to public;







-- show sizes of database, order by name not size
create view size_database as
SELECT 
	pg_database.datname, 
	pg_size_pretty(pg_database_size(pg_database.datname)) AS size 
	FROM pg_database 
	order by pg_database.datname ;
grant all on table size_database to public;


-- count of user connections to all databases
create view users as
  select
    usename,
    datname,
    count(*)
  from pg_stat_activity
  group by usename,datname order by 3 desc
;
grant all on table users to public;


create view users2 as
select 
	usename, 
	application_name, 
	datname, 
	client_addr, 
	to_char( now() - backend_start, 'HH24:MI:SS') as duration, 
	pid, 
	waiting		
	from pg_stat_activity  
	order by usename, duration desc
;
grant all on table users2 to public;



-- current queries being performed, ordered by longest running
create view queries as
  select 
    to_char( now() - backend_start, 'HH24:MI:SS') as b_duration,
    to_char( now() - query_start, 'HH24:MI:SS') as q_duration,
    pid as pid,
    usename as role,
    datname as database,
    regexp_replace( query, '\r|\n', '', 'g') as query
  from pg_stat_activity
--  where current_query != '<IDLE>'
  order by q_duration desc
;
grant all on table queries to public;


----- locks stuff


create view locks as
select
        d.datname as database,

        n.nspname as schema,
        o.relname as relation,

        a.usename,
        to_char( now() - a.query_start, 'HH24:MI:SS') as duration,
        to_char( now() - a.backend_start, 'HH24:MI:SS') as bduration,

        pg_locks.locktype ,
--      pg_locks.page, 
        pg_locks.tuple,
        pg_locks.virtualxid,
        pg_locks.transactionid,
        pg_locks.pid,
        pg_locks.mode,
        pg_locks.granted

--      a.query

        from pg_locks
        join pg_class o on o.relfilenode=pg_locks.relation
        join pg_namespace n on n.oid=o.relnamespace

        join pg_database d ON pg_locks.database = d.oid
        join pg_stat_activity a ON a.pid = pg_locks.pid  -- ok, since only one query per connction.

        order by mode desc, pid;




grant all on table locks to public;
-- locktype  | database | relation | page | tuple | virtualxid | transactionid | classid | objid | objsubid | virtualtransaction |  pid  |      mode       | granted

-- SELECT bl.pid                 AS blocked_pid,
  --       a.usename              AS blocked_user,
   --      ka.current_query       AS blocking_statement,
    --     now() - ka.query_start AS blocking_duration,
    --     kl.pid                 AS blocking_pid,
    --     ka.usename             AS blocking_user,
    --     a.current_query        AS blocked_statement,
    --     now() - a.query_start  AS blocked_duration,
--	bl.granted 
 -- FROM  pg_catalog.pg_locks         bl
 --  JOIN pg_catalog.pg_stat_activity a  ON a.procpid = bl.pid
  -- JOIN pg_catalog.pg_locks         kl ON kl.transactionid = bl.transactionid AND kl.pid != bl.pid
   -- JOIN pg_catalog.pg_stat_activity ka ON ka.procpid = kl.pid
  --WHERE NOT bl.granted and a.usename like '$1%' and a.datname='$2';
-- ;







create view locks1 as
  select pg_class.relname,
      pg_locks.*
  from pg_class,pg_locks
  where pg_class.relfilenode=pg_locks.relation
;
grant all on table locks1 to public;


create view locks2 as
  SELECT bl.pid          AS blocked_pid,
    a.usename       AS blocked_user,
    kl.pid          AS blocking_pid,
    ka.usename      AS blocking_user,
    a.query AS blocked_statement
  FROM  pg_catalog.pg_locks         bl
    JOIN pg_catalog.pg_stat_activity a  ON a.pid = bl.pid
    JOIN pg_catalog.pg_locks         kl ON kl.transactionid = bl.transactionid AND kl.pid != bl.pid
    JOIN pg_catalog.pg_stat_activity ka ON ka.pid = kl.pid
  WHERE NOT bl.granted
;
grant all on table locks2 to public;


create view locks3 as
  SELECT bl.pid                 AS blocked_pid,
         a.usename              AS blocked_user,
         ka.query       AS blocking_statement,
         now() - ka.query_start AS blocking_duration,
         kl.pid                 AS blocking_pid,
         ka.usename             AS blocking_user,
         a.query        AS blocked_statement,
         now() - a.query_start  AS blocked_duration
  FROM  pg_catalog.pg_locks         bl
   JOIN pg_catalog.pg_stat_activity a  ON a.pid = bl.pid
   JOIN pg_catalog.pg_locks         kl ON kl.transactionid = bl.transactionid AND kl.pid != bl.pid
   JOIN pg_catalog.pg_stat_activity ka ON ka.pid = kl.pid
  WHERE NOT bl.granted
;
grant all on table locks3 to public;


-- For PostgreSQL 9.1
create view locks4 as
  select l.mode, l.locktype, to_char( now() - query_start, 'HH24:MI:SS') as duration,
  usename,
  datname,
  l.pid,
  sa.query
  from pg_locks l
  inner join pg_stat_activity sa
      on l.pid = sa.pid
  where l.mode like '%xclusive%'
  order by duration desc
;
grant all on table locks4 to public;



create function terminate_user_sessions( owner text ) returns void
language plpgsql volatile
as $$
	begin
	select pg_terminate_backend( pid )	
	from admin.queries 
	where role = $1;
	end
$$;
grant all on function terminate_user_sessions( owner text ) to public;


create function cancel_user_sessions( owner text ) returns void
language plpgsql volatile
as $$
	begin
	select pg_cancel_backend( pid ) 
	from admin.queries 
	where role = $1;
	end
$$;
grant all on function cancel_user_sessions( owner text ) to public;




-- postgres uses very fine grained ACLs, so these functions are useful to work at schema level

-- set owner of schema and all objects within it.
create function set_owner_of_schema_objects( schema text, owner text ) returns void
language plpgsql volatile
as $$
  begin
    -- should we change the schema owner here as well ?
    perform admin.exec( 'alter schema '||$1||' owner to '||$2 ) ;

    -- note that when we change the table owner, the index owner changes as well
    -- also 'alter table' syntax appears work for views and sequences as well
    perform admin.exec( 'alter view '||$1||'.'||c.name||' owner to '||$2 )
    from admin.objects c
    where c.kind = 'v'
    and c.schema = $1;

    perform admin.exec( 'alter table '||$1||'.'||c.name||' owner to '||$2 )
    from admin.objects c
    where c.kind = 'r'
    and c.schema = $1;

    perform admin.exec( 'alter sequence '||$1||'.'||c.name||' owner to '||$2 )
    from admin.objects c
    where c.kind = 'S'
    and c.schema = $1;

    perform admin.exec( 'alter function '||f.fullname||' owner to '||$2 )
    from admin.functions f
    where f.schema = $1;
  end;
$$;
grant all on function set_owner_of_schema_objects( schema text, owner text ) to public;


-- should we also do default privileges here?
-- remember should be run as postgres, probably bad to set defaults manually anyway.

create function grant_read_on_schema_and_objects( schema text, role text ) returns void
language plpgsql volatile
as $$
  begin
    perform admin.exec(
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
    perform admin.exec(
        'grant all on schema '||$1||' to '||$2||';'
        'grant all on ALL TABLES IN SCHEMA '||$1||' to '||$2||';'
        'grant all on ALL sequences IN SCHEMA '||$1||' to '||$2||';'
        'grant all on ALL functions IN SCHEMA '||$1||' to '||$2||';'
  );
  end;
$$;
grant all on function grant_write_on_schema_and_objects( schema text, role text ) to public;


-- revoke all grants - revoke all is sufficient, since we can rebuild up from no grants
create function revoke_all_on_schema_and_objects( schema text, role text ) returns void
language plpgsql volatile
as $$
  begin
    perform admin.exec(
        'revoke all on schema '||$1||' from '||$2||';'
        'revoke all on ALL TABLES IN SCHEMA '||$1||' from '||$2||';'
        'revoke all on ALL sequences IN SCHEMA '||$1||' from '||$2||';'
        'revoke all on ALL functions IN SCHEMA '||$1||' from '||$2||';'
  );
  end;
$$;
grant all on function revoke_all_on_schema_and_objects( schema text, role text ) to public; 


-- revoke all default privileges for objects types on a schema
create function revoke_defaults_on_schema( schema text ) returns void
language plpgsql volatile
as $$
  begin
	perform admin.exec( 'alter default privileges in schema '||d.schema||' for role '||grantor||' revoke '||privilege||' on tables from '||grantee)  
	from admin.defaults2 d 
	where kind = 'r';

	perform admin.exec( 'alter default privileges in schema '||d.schema||' for role '||grantor||' revoke '||privilege||' on sequences from '||grantee)  
	from admin.defaults2 d 
	where kind = 'S';

	perform admin.exec( 'alter default privileges in schema '||d.schema||' for role '||grantor||' revoke '||privilege||' on functions from '||grantee)  
	from admin.defaults2 d 
	where kind = 'f';
  end;
$$;
grant all on function revoke_defaults_on_schema( schema text )  to public; 



create function drop_objects_in_schema( schema text ) returns void
language plpgsql volatile
as $$
    begin
    perform admin.exec( 'drop view if exists '||n.nspname||'.'||o.relname||' cascade' )
    from pg_class o
    left join pg_namespace n on n.oid=o.relnamespace
    where o.relkind = 'v'
    and n.nspname = $1;

    perform admin.exec( 'alter table '||n.nspname||'.'||r.relname||' drop constraint if exists '||c.conname||' cascade' )
    from pg_constraint c
    left join pg_namespace n on n.oid = c.connamespace
    left join pg_class r ON r.oid = c.conrelid
    where n.nspname = $1;

    perform admin.exec( 'drop index if exists '||n.nspname||'.'||o.relname||' cascade' )
    from pg_class o
    left join pg_namespace n on n.oid = o.relnamespace
    where o.relkind = 'i'
    and n.nspname = $1;

    perform admin.exec( 'drop table if exists '||n.nspname||'.'||o.relname||' cascade' )
    from pg_class o
    left join pg_namespace n on n.oid = o.relnamespace
    where o.relkind = 'r'
    and n.nspname = $1;

    perform admin.exec( 'drop sequence if exists '||n.nspname||'.'||o.relname|| ' cascade' )
    from pg_class o
    left join pg_namespace n on n.oid = o.relnamespace
    where o.relkind = 'S'
    and n.nspname = $1;

    perform admin.exec( 'drop function if exists '||p.oid::regproc||'('||pg_get_function_identity_arguments( p.oid)||')'||' cascade' )
    FROM pg_proc p
    left join pg_namespace n ON n.oid = p.pronamespace
    where n.nspname = $1;
    end;
$$;

grant all on function drop_objects_in_schema( schema text ) to public; 






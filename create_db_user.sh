
# create a new user
sudo -u postgres psql -c 'drop user meteo'
sudo -u postgres psql -c 'create user meteo password $$meteo$$ '
sudo -u postgres psql -c 'alter user meteo createdb'

# if [ grep -q '127.0.0.1:5432:\*:meteo:meteo' ~/.pgpass ]; then echo 'have entry' fi

echo '127.0.0.1:5432:*:meteo:meteo' > ~/.pgpass

# can now connect like this and create db etc.
psql -h 127.0.0.1 -U meteo


#!/usr/bin/ruby


def query_basic( port, user, database, cmd)
  # We have to run on the target machine for the OS stuff
  # so there's no point specifying a host
  `psql  #{user ? "-U #{user}" : ""}  -p #{port} -d #{database} -w -c "#{cmd}"`

end

# Note if we wanted then we can get bytes read and bytes written by process from 
# looking at the /proc/xxx/stat etc  

# Get OS paramter in terms of process id
def param_from_pid( param )
  tuples = {}
  `ps -eo pid,#{param}`.split("\n").each_with_index() do |row, index|
    next unless index > 0
    cols = row.split(' ')
    tuples[cols[0]] = cols[1]
  end
  tuples
end


mem_from_pid = param_from_pid( '%mem' )
cpu_from_pid = param_from_pid( '%cpu' )
# puts cpu_from_pid


puts query_basic( 5432, 'postgres', 'postgres', <<-EOS
  select to_char( now() - query_start, 'HH24:MI:SS') as duration,
  mem.mem,
  cpu.cpu,
  procpid, usename, datname,
  regexp_replace( current_query, '\r|\n', '', 'g')
  from pg_stat_activity

  left join
  ( VALUES #{
    l = mem_from_pid.map() do |key,val|
      "(#{key}, #{ mem_from_pid[key]}) "
    end
    l.join(", ")
  }
  ) as mem (pid, mem)
  on procpid = mem.pid


  left join
  ( VALUES #{
    l = cpu_from_pid.map() do |key,val|
      "(#{key}, #{ cpu_from_pid[key]}) "
    end
    l.join(", ")
  }
  ) as cpu (pid, cpu)
  on procpid = cpu.pid

  -- where current_query != '<IDLE>'

  order     by duration desc
  EOS
)


abort( 'finished')



def tuplize( s)
  rows = s.split("\n")
  names = rows[ 0].split('|').map() { |name| name = name.strip() }
  tuples = []
  rows.each_with_index {|row, n|
    next unless n >= 2
    tuple = {}
    row.split( '|').each_with_index() { |val, col|
      tuple[names[col].to_sym] = val.strip()
    }
    tuples << tuple
  }
  tuples
end



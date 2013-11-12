# This type/provider handles individual entries in a file in /var/lib/alternatives.
# If you create an alternative for which there is no such file yet, it will be automatically created.
# If you remove the last alternative in a file, the file is automatically deleted.
#
# The title of this resource is composite: <name>:<path> where name is a generic name of the alternative
# (e.g. 'editor') and path is an actual file on the file system (e.g. '/usr/bin/vim')
# The link attribute is normally /usr/bin/<name> (this is the default value)
# The default value for priority is '10'
#
# After making modifications using this resource, it is possible that the alternative changes
# to manual mode. If this is not what you want, You can change it back to auto mode using the 
# alternatives resource.
#
# Usage examples:
#
#  alternative { 'test2:/usr/bin/vmstat':
#    ensure   => present,
#    link     => '/usr/bin/test2',
#    priority => '2',
#  }
#
#  alternative { 'editor:/usr/bin/vim':
#    ensure   => present,
#  }
#
#
# With slave links: ( = hash or array of hashes)
#
#  alternative { 'editor:/usr/bin/vim':
#    ensure => present,
#    slave  => [{name => "t1", link => "/usr/bin/t1", path => "/usr/bin/xyz"},
#               ...
#              ],
#  }
#

Puppet::Type.type(:alternative).provide(:rhel) do

  defaultfor :osfamily => :redhat
  confine    :osfamily => :redhat

  commands :update => 'update-alternatives'
  commands :ls => 'ls'

  # Return all instances for this provider
  #
  # @return [Array<Puppet::Type::Alternative::ProviderRhel>] A list of all current provider instances
  def self.instances
    # The title here will be parsed using the pattern in method title_pattern (defined in type sourcefile)
    # So in this case it has to be like <name>:<path>
    ret = all.map { |title, attributes| new(:name => title, :path => attributes[:path],
                                           :priority => attributes[:priority]) }
    return ret
  end

  # Generate a hash of hashes containing a link name and associated properties
  #
  # This is structured as {'key' => {attributes}} to do fast lookups on entries
  #
  # @return [Hash<String, Hash<Symbol, String>>]
  def self.all
    output = ls('/var/lib/alternatives') 
    output.split(/\n/).inject({}) do |hash, line|
      name = line
      paths = fetch_paths(name)
      paths.each do |path|
        #  name or path is not always unique -> combine name + path,
        #  also required because it will be parsed by title_patterns.
        hash[name + ":" + path[:path]] = path
      end
      hash
    end
  end

  # Retrieve the path of this alternative. Path is part of the composite namevar (together with name) 
  def path
    @resource.value(:path)
  end

  # Retrieve the alternative's link.
  # This is the second line in the file in /var/lib/alternatives
  # (or /var/lib/dpkg/alternatives on a Debian system)
  def link
    self.class.fetch_link(@resource.value(:name))
  end

  def link=(_)
    # Is it possible to update the (sym)link of an existing alternative?
  end

  # Retrieve the alternative's priority
  def priority
    name = @resource.value(:name)
    path = @resource.value(:path)
    if (attrs = self.class.all[name + ":" + path])
      attrs[:priority]
    end
  end

  def priority=(_)
    # Call create method; this is ok because when the alternative already exists,
    # using the --install option will update the existing alternative.
    create() 
  end

  def slave
    # Fetch existing config into variables, otherwise
    # puppet will apply the resource each time.
    #
    # to parse: skip 1st and 2nd line 
    # then: each 2 lines: slave name + symlink
    #  until an empty line is found.
    #
    slaveparams = []
    slave_paths = fetch_slave_paths(@resource.value(:path))
    alternatives_file = IO.readlines("/var/lib/alternatives/" + @resource.value(:name))
    alternatives_file.shift
    alternatives_file.shift
    while !alternatives_file.empty? do 
      slave_name = alternatives_file.shift.strip
      if slave_name =~ /^$/m
        break
      end
      slave_link = alternatives_file.shift.strip
      slave_path = fetch_slave_path(slave_paths, slave_name) 
      slave_hash = { 'link' => slave_link, 'name' => slave_name, 'path' => slave_path }
      slaveparams.push(slave_hash)
    end
    slaveparams
  end

  def slave=(newslaveparams)
    newslaveparams = [newslaveparams] unless newslaveparams.is_a?(Array)
    create()
  end

  def self.fetch_link(alternative_name)
    alternatives_file = IO.readlines("/var/lib/alternatives/" + alternative_name)
    return alternatives_file[1].strip
  end

  def self.fetch_paths(alternative_name)
    output = update('--display', alternative_name)
    output_lines = output.split("\n")
    paths = []
    output_lines.each do |line|
      if line =~ /^(\/.*) - priority (.*)/
        path_info = {:path => $1, :priority => $2}
        paths.push(path_info)
      end
    end
    return paths
  end

  # Far too complicated logic to get the 'slave' lines for the alternative
  def fetch_slave_paths(alternative_path)
    alternatives_output = update('--display', @resource.value(:name)).split("\n")
    alternatives_output.shift
    output_line = alternatives_output.shift
    slave_paths = []
    while !alternatives_output.empty? and !(output_line =~ /^#{Regexp.escape(alternative_path)}/) do
      output_line = alternatives_output.shift
    end
    if !alternatives_output.empty?
      output_line = alternatives_output.shift
      while !alternatives_output.empty? and output_line =~ /^ slave .*/m do
        slave_paths.push(output_line.strip)
        output_line = alternatives_output.shift
      end
    end
    return slave_paths
  end

  def fetch_slave_path(slave_paths, slave_name)
    slave_paths.each do |line|
      if line =~ /slave #{slave_name}: (.*)/ 
        return $1
      end
    end
  end

  def exists?
    begin
      name = @resource.value(:name)
      # Hack because I don't know why the name is still <name>:<path>
      # and not parsed by title_patterns when calling 'puppet resource alternative' to 
      # list all resources
      if name =~ /^(.*):(.*)$/m
        name= $1
        resource[:name] = name
      end
      path = @resource.value(:path)

      output = update("--display", name)
      # If execution was ok: check if name/path exists as an alternative.
      # Loop over the output lines and check if the path is found:
      output_lines = output.split("\n")
      output_lines.each do |line|
        if line =~ /^#{Regexp.escape(path)}.*/ 
          return true
        end
      end
      return false
    rescue Puppet::ExecutionFailure => e
      return false
    end
  end

  def create
    link = @resource.value(:link)
    name = @resource.value(:name)
    path = @resource.value(:path)
    priority = @resource.value(:priority)
    # Parse (optional) slave parameter (value = hash or array of hashes)
    cmd = ['--install', link, name, path, priority]
    if slaveparams = @resource.value(:slave)
      slaveparams = [slaveparams] unless slaveparams.is_a?(Array)
      slaveparams.each do |slaveparam|
        cmd << '--slave' << slaveparam['link'] << slaveparam['name'] << slaveparam['path']
      end
    end
    update(*cmd) 
  end

  def destroy
    name = @resource.value(:name)
    path = @resource.value(:path)
    update('--remove', name, path)
  end 
end

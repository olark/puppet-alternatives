
Puppet::Type.type(:alternatives).provide(:rhel) do

  defaultfor :osfamily => :redhat
  confine    :osfamily => :redhat

  commands :update => '/usr/sbin/update-alternatives'
  commands :ls => 'ls'

  has_feature :mode

  # Return all instances for this provider
  #
  # @return [Array<Puppet::Type::Alternatives::ProviderDpkg>] A list of all current provider instances
  def self.instances
    ret = all.map { |name, attributes| new(:name => name, :path => attributes[:path]) }
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
      path = fetch_path(name)
      hash[name] = {:path => path}
      hash
    end
  end

  # Retrieve the current path link
  def path
    name = @resource.value(:name)
    if (attrs = self.class.all[name])
      attrs[:path]
    end
  end

  # @param [String] newpath The path to use as the new alternative link
  def path=(newpath)
    name = @resource.value(:name)
    update('--set', name, newpath)
  end

  # @return [String] The alternative mode
  def mode
    self.class.fetch_mode(@resource.value(:name))
  end

  # Set the mode to auto. (rem. switching back to manual is not possible here)
  def mode=(_)
    update('--auto', @resource.value(:name))
  end

  def self.fetch_path(masterlink)
    output = update('--display', masterlink)
    output_array = output.split("\n")
    output_array.shift
    first = output_array.first

    if first =~ /link currently points to (.*)$/
      $1
    else
      raise Puppet::Error, "Could not determine path for #{masterlink}"
    end
  end

  def self.fetch_mode(masterlink)
    output = update('--display', masterlink)
    first = output.split("\n").first

    if first.include? "auto"
      'auto'
    elsif first.include? "manual"
      'manual'
    else
      raise Puppet::Error, "Could not determine if #{masterlink} is in auto or manual mode"
    end
  end
end

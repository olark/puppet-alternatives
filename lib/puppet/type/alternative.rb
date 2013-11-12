Puppet::Type.newtype(:alternative) do

  ensurable

  def self.title_patterns
    # The 'boobies' regex :p
    [ [ /(.*):(.*)/m, [ [key_attributes[0]], [key_attributes[1] ] ] ] ]
  end

  newparam(:name, :namevar => true) do
    desc "The name of the alternative."
  end

  newparam(:path, :namevar => true) do
    desc "The path of the desired source for the given alternative"

    validate do |path|
      raise ArgumentError, "path must be a fully qualified path" unless absolute_path? path
    end
  end

  newproperty (:link) do
    defaultto  { "/usr/bin/" + @resource[:name] }
    desc "The symlink that is used by this alternative"
  end

  newproperty(:priority) do
    defaultto "10"
    desc "Priority of this alternative path"
  end

  newproperty(:slave, :array_matching => :all) do
    defaultto []
    desc "Optional slave link configuration"

    def insync?(currentvalue)
      current_array = []
      should_array = []
      if !currentvalue.is_a?Array
        current_array = [currentvalue]
      else
        current_array = currentvalue
      end
      if !@should.is_a?Array
        should_array = [@should]
      else
        should_array = @should
      end
      if current_array.size != should_array.size
        return false
      end
      current_array.each_with_index do |item, index|
        # Because hashes are not yet 'sorted' in ruby 1.8: call the sort method
        # To convert to 'sorted' array:
        if item.sort != should_array[index].sort
          return false
        end
      end
      return true
    end
  end
end

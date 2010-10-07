module Puppet::Parser::Functions
    newfunction(:augeas_array_to_changes, :type => :rvalue) do |args|

        path = args.shift
        changes = Array.new

        args[0].each_with_index do |arg, i|
            changes << "set #{path}[#{i+1}] '#{arg}'"
        end

        changes
    end
end

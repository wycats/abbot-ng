module SproutCore
  class Requirements < Hash
    include TSort

    alias tsort_each_node each_key

    def tsort_each_child(node, &block)
      fetch(node, []).each(&block)
    end
  end

  class Buildfile
    def self.instance
      @instance ||= new
    end

    def self.evaluate(buildfile)
      contents = File.read(buildfile)
      instance.instance_eval(contents, buildfile, 0)
    end

    # Get a list of ordered requirements for a root target
    # in a given mode
    def self.requirements(mode = :global, target = :all)
      requirements = Requirements.new
      hash = instance.modes[mode]

      instance.requirements_for(mode, target).each do |req|
        requirements[req] = Array(hash[req][:required])
      end

      requirements.tsort
    end

    attr_reader :modes

    def initialize
      # default to a two-level nested hash
      @modes = Hash.new { |h,k| h[k] = Hash.new { |h,k| h[k] = {} } }
      @current_mode = @modes[:global]
    end

    # Specify configuration for a particular mode. By default,
    # configuration is added to the global mode
    def mode(name, &block)
      @current_mode, original_mode = @modes[name], @current_mode
      instance_eval(&block)
    ensure
      @current_mode = original_mode
    end

    # Merge in the new config hash with the current config Hash
    #
    # If an element is an Array or a Hash, merge it in with the
    # existing Array or Hash. Otherwise, set the value.
    def config(name, hash)
      config = @current_mode[name.to_sym]

      hash.each do |k,v|
        case v
        when Array
          config[k] ||= []
          config[k].concat(v)
        when Hash
          config[k] ||= {}
          config[k].merge!(v)
        else
          config[k] = v
        end
      end
    end

    def requirements_for(mode, target, requirements = [])
      reqs = Array(@modes[mode][target][:required])
      requirements.concat(reqs)
      reqs.each do |req|
        requirements_for(mode, req, requirements)
      end
      requirements.uniq
    end
  end
end

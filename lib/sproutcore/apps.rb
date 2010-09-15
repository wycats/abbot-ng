module SproutCore
  class Target
    attr_reader :javascripts, :stylesheets, :target_name

    # Only create one Target instance for a given location. When a file in the
    # Target changes, we can expire everything about the target in one shot.
    def self.new(directory, combine)
      targets[directory] ||= super
    end

    def self.targets
      @targets ||= {}
    end

    def initialize(directory, combine)
      target_name  = File.basename(directory)
      target_root  = File.dirname(directory)
      target_type  = File.basename(target_root)
      package_root = File.dirname(target_root)

      @root, @target_name, @target_type, @combine = package_root, target_name, target_type, combine
    end

    def setup_target(app)
      @statics = StaticEntries.new(@root, @target_name, @target_type).app(app)

      @javascripts = JavaScriptEntries.from_directory(@root, @target_name, @target_type).app(app).associate_statics(@statics)
      @javascripts.combine("javascript.js") if @combine

      @stylesheets = CssEntries.from_directory(@root, @target_name, @target_type).app(app).associate_statics(@statics)
      @stylesheets.combine("stylesheet.css") if @combine

      self
    end

    def find_static(static)
      @statics.find_static(static)
    end
  end

  class Apps
    def initialize
      @app_names  = {}

      # NOTE: Ruby 1.8 does not preserve hash order (if we care)
      @roots      = {}
      @apps       = {}
    end

    def app?(name)
      @app_names.key?(name)
    end

    # Return the app for a particular name. For frameworks and themes that are
    # not part of an app, we use the special "all" app name
    def app_for(name)
      app_name = app?(name) ? name : "all"

      @apps[name] ||= App.new(app_name, @roots)
    end

    # Add a new root. Load in the Buildfile at the root as well
    def add_root(root, combine = true)
      root = File.expand_path(root)

      Dir["#{root}/apps/*"].each do |app|
        @app_names[File.basename(app)] = nil
      end

      Buildfile.evaluate("#{root}/Buildfile") if File.exist?("#{root}/Buildfile")
      @roots[root] = combine
    end
  end

  class App

    # Every app has every root in its targets, but doesn't have other application
    # targets (just frameworks and themes)
    def initialize(app, roots)
      @targets = {}
      @roots   = {}
      @app     = app

      roots.each { |root, combine| add_root(root, combine) }
      add_targets
    end

    def to_s
      "#<App: #{@app}>"
    end

    # Search for statics from the most specific to least specific (from the current
    # target down the dependency chain)
    def find_static(static)
      @targets.reverse_each.find do |name, target|
        if found_static = target.find_static(static)
          return found_static
        end
      end
    end

    MIMES     = {"png" => "image/png"}

    def content_for(url, filename)
      case filename
      when /\.js$/
        each_javascript do |list|
          body = list.content_for(url)
          return ["application/javascript", body] if body
        end
      when /\.css$/
        each_stylesheet do |list|
          body = list.content_for(url)
          return ["text/css", body] if body
        end
      else
        if file = find_static(filename)
          return [MIMES[file.source[/^.*\.([^\.]*)$/, 1]], File.open(file.source, "rb")]
        end
      end
    end

    def each_javascript
      @targets.each do |name, target|
        yield target.javascripts
      end
      nil
    end

    def each_stylesheet
      @targets.each do |name, target|
        yield target.stylesheets
      end
      nil
    end

    # get the combined bootstrap file
    def bootstrap
      @targets["bootstrap"].javascripts.destinations.keys.first
    end

  private
    def add_root(root, combine = true)
      @roots[root] = combine
    end

    def add_targets
      requirements = Buildfile.requirements(:global, :sproutweets)
      unsatisfied  = requirements.dup

      roots = @roots.dup

      # TODO: Get mode and target from config

      Buildfile.requirements(:global, :sproutweets).each do |requirement|
        roots.each do |root, combine|
          Dir["#{root}/frameworks/#{requirement}"].each do |target|
            unsatisfied.delete(requirement)
            add_target(target, combine)
          end

          Dir["#{root}/frameworks/bootstrap"].each do |target|
            add_target(target, combine)
          end
        end
      end

     roots.each do |root, combine|
        # TODO: Get theme name from config
        theme = "#{root}/themes/standard_theme"
        add_target(theme, combine) if File.exist?(theme)

        app = "#{root}/apps/#{@app}"
        add_target(app, combine) if File.exist?(app)
      end
      self
    end

    def add_target(directory, combine = true)
      target = Target.targets[directory] || Target.new(directory, combine).setup_target(self)
      @targets[target.target_name] = target
    end
  end
end


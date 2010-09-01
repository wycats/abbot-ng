module SproutCore
  class Target
    attr_reader :javascripts, :stylesheets

    def self.new(root, target, target_type, combine)
      @targets ||= Hash.new { |h,k| h[k] = Hash.new { |h,k| h[k] = {} } }
      @targets[root][target][target_type] ||= super
    end

    def initialize(root, target, target_type, combine)
      @root, @target, @target_type, @combine = root, target, target_type, combine
      @setup = false
    end

    def setup_target(app)
      return self if @setup
      @setup = true

      @javascripts = JavaScriptEntries.from_directory(@root, @target, @target_type).app(app)
      @javascripts.combine("javascript.js") if @combine

      @statics = StaticEntries.new(@root, @target, @target_type).app(app)

      @stylesheets = CssEntries.from_directory(@root, @target, @target_type).app(app).associate_statics(@statics)
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

    def app?(app)
      @app_names.key?(app)
    end

    def app_for(app)
      name = app?(app) ? app : "all"

      return @apps[name] if @apps.key?(name)

      application = App.new(name)
      @roots.each do |root, combine|
        application.add_root(root, combine)
      end
      application.add_targets
      @apps[name] = application
    end

    def add_root(root, combine = true)
      Dir["#{root}/apps/*"].each do |app|
        @app_names[File.basename(app)] = nil
      end

      root = File.expand_path(root)
      Buildfile.evaluate("#{root}/Buildfile")
      @roots[root] = combine
    end
  end

  class App
    def initialize(app)
      @targets = {}
      @roots   = {}
      @app     = app
    end

    def to_s
      "#<App: #{@app}>"
    end

    def add_root(root, combine = true)
      @roots[root] = combine
    end

    def add_targets
      @roots.each do |root, combine|
        # TODO: Get mode and target from config
        Buildfile.requirements(:global, :all).each do |requirement|
          Dir["#{root}/frameworks/{#{requirement},bootstrap}"].each do |target|
            add_target(target, combine)
          end
        end

        # TODO: Get theme name from config
        theme = "#{root}/themes/standard_theme"
        add_target(theme, combine) if File.exist?(theme)

        app = "#{root}/apps/#{@app}"
        add_target(app, combine) if File.exist?(app)
      end
    end

    def add_target(directory, combine = true)
      target_name  = File.basename(directory)
      target_root  = File.dirname(directory)
      target_type  = File.basename(target_root)
      package_root = File.dirname(target_root)

      @targets[target_name] = Target.new(package_root, target_name, target_type, combine).setup_target(self)
    end

    def find_static(static)
      @targets.find do |name, target|
        if found_static = target.find_static(static)
          return found_static
        end
      end
    end

    def each_javascript
      @targets.each do |name, target|
        yield target.javascripts
      end
    end

    def each_stylesheet
      @targets.each do |name, target|
        yield target.stylesheets
      end
    end

    def find_js(js_target)
      @targets[js_target].javascripts
    end

    def find_css(css_target)
      @targets[css_target].stylesheets
    end
  end
end


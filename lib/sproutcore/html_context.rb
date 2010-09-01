module SproutCore
  class HtmlContext
    def initialize(config, apps)
      @config, @apps = config, apps
    end

    def sc_static(static)
      if found_static = @app.find_static(static)
        found_static.destination
      else
        puts "WARN: #{static} could not be found in any of the loaded frameworks, themes, or your app"
        puts "from #{caller[0]}"
        ""
      end
    end

    def bootstrap
      location = @app.find_js("bootstrap").destinations.keys.first
      %{<script type='text/javascript' src="#{location}"></script>}
    end

    def stylesheets
      sheets = []
      @app.each_stylesheet do |list|
        list.destinations.each do |location, source|
          sheets << %{<link href="#{location}" rel="stylesheet" type="text/css" />}
        end
      end
      sheets.join("\n    ")
    end

    def javascripts
      scripts = []
      @app.each_javascript do |list|
        list.destinations.each do |location, source|
          scripts << %{<script type="text/javascript" src="#{location}"></script>}
        end
      end
      scripts << %{<script type="text/javascript">String.preferredLanguage = "en";</script>}
      scripts.join("\n    ")
    end
  end
end

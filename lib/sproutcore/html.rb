module SproutCore
  class HtmlContext
    def initialize(config, manifest)
      @config, @manifest = config, manifest
    end

    def sc_static(static)
      if static = manifest.find_static(static)
        static.destination
      else
        raise "#{static} could not be found in any of the loaded frameworks, themes, or your app"
      end
    end

    def bootstrap
      location = @manifest.find_js("bootstrap").destination
      %{<script type='text/javascript' src="#{location}"></script>}
    end

    def stylesheets
      sheets = []
      @manifest.stylesheets.each do |name, list|
        location = list.destination
        sheets = %{<link href="#{location} rel="stylesheet" type="text/css" />}
      end
      sheets.join("\n")
    end

    def javascripts
      scripts = []
      @manifest.javascripts.each do |name, list|
        location = list.destination
        scripts << %{<script type="text/javascript" src="#{location}"></script>}
      end
      scripts << %{<script type="text/javascript>String.preferredLanguage = "en";</script>}
      scripts.join("\n")
    end
  end
end

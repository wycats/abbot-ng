module SproutCore
  class Manifest
    attr_reader :javascripts, :stylesheets

    def initialize
      @javascripts = {}
      @stylesheets = {}
      @statics     = {}
    end

    def add_target(root, target, target_type)
      @javascripts[target]       = JavaScriptEntries.from_directory(root, target, target_type).manifest(self)
      statics = @statics[target] = StaticEntries.new(root, target, target_type).manifest(self)
      @stylesheets[target]       = CssEntries.from_directory(root, target, target_type).manifest(self).associate_statics(statics)
    end

    def find_static(static)
      @statics.each do |target, list|
        if found_static = list.find_static(static)
          return found_static
        end
      end
      nil
    end

    def find_js(js_target)
      @javascripts.find { |target, list| target == js_target }.last
    end

    def find_css(css_target)
      @stylesheets.find { |target, list| target == css_target }.last
    end
  end
end

__END__

manifest = SproutCore::Manifest.new

require "benchmark"

puts Benchmark.measure {
  %w(bootstrap runtime foundation datastore statechart desktop media).each do |target|
    manifest.add_target("~/Code/sprout/sproutcore", target, :frameworks)
  end

  manifest.add_target("~/Code/sprout/sproutcore", "standard_theme", :themes)
}

puts Benchmark.measure {
  manifest.javascripts.each do |name, js|
    puts "Compiling JS: #{name}"
    js.compile
  end

  manifest.stylesheets.each do |name, css|
    puts "Compiling CSS: #{name}"
    css.compile
  end
}


# p manifest.find_static("sproutcore-logo.png")

#manifest.add_target("~/Code/sprout/sproutcore", "standard_theme", :themes)

#manifest.stylesheets

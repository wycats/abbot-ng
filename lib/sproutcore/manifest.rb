module SproutCore
  class Manifest
    def initialize
      @javascripts = {}
      @stylesheets = {}
    end

    def add_target(root, target, target_type)
      @javascripts[target] = JavaScriptEntries.from_directory(root, target, target_type).manifest(self)
      @stylesheets[target] = CssEntries.from_directory(root, target, target_type).manifest(self)
    end

    def puts(*)
    end

    def find_static(static)
      @stylesheets.each do |target, list|
        if found_static = list.statics[static]
          return found_static
        end
      end
      nil
    end

    def javascripts
      @javascripts.each do |k,v|
        puts
        puts k
        puts "<<<<========================>>>>"
        puts v.compile
        puts
      end
    end

    def stylesheets
      @stylesheets.each do |k,v|
        puts
        puts k
        puts "<<<<========================>>>>"
        puts v.compile
        puts
      end
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

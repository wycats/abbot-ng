require "spec_helper"

describe "the Buildfile" do
  before do
    SproutCore::Buildfile.evaluate(SproutCore::Specs::BUILDFILE)
    SproutCore::Buildfile.evaluate(SproutCore::Specs::BUILDFILE + ".app")
  end

  class DependsOn
    def initialize(expected, requirements)
      @expected, @requirements = expected, requirements
    end

    def matches?(actual)
      @requirements.index(@expected) < @requirements.index(actual)
    end
  end

  def depend_on(expected)
    DependsOn.new(expected, @requirements)
  end

  it "exposes the required targets for a mode's target" do
    @requirements = SproutCore::Buildfile.requirements(:global, :all)
    :foundation.should depend_on(:jquery)
    :foundation.should depend_on(:runtime)
    :desktop.   should depend_on(:jquery)
    :desktop.   should depend_on(:runtime)
    :sproutcore.should depend_on(:desktop)
    :sproutcore.should depend_on(:datastore)
    :sproutcore.should depend_on(:foundation)
    :sproutcore.should depend_on(:runtime)
    :sproutcore.should depend_on(:jquery)
  end
end

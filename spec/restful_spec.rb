require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

describe Restful do

  it "should have an api_prefix accessor" do
    Restful.api_prefix.should be_nil
    Restful.api_prefix = 'foo'
    Restful.api_prefix.should == 'foo'
  end

  it "should have a model_configuration accessor" do
    Restful.model_configuration.should == {}
  end

  it "should automatically symbolize keys for model_configuration" do
    Restful.model_configuration = { 'foo' => 'bar' }
    Restful.model_configuration.should == { :foo => 'bar' }
  end

  describe "looking up model configurations" do

    class Foo; end
    class FooBar < Foo; end

    before(:each) do
      Restful.model_configuration = {
        :foo => :foo_config,
        :foo_bar => :foo_bar_config,
      }
    end

    it "should return an empty hash if no configuration" do
      Restful.model_configuration_for(nil).should == {}
    end

    it "should lookup entries by symbol" do
      Restful.model_configuration_for(:foo).should == :foo_config
    end

    it "should lookup entries from a string" do
      Restful.model_configuration_for('foo').should == :foo_config
    end

    it "should lookup entries by Class" do
      Restful.model_configuration_for(Foo).should == :foo_config
      Restful.model_configuration_for(FooBar).should == :foo_bar_config
    end

    it "should lookup entries by instance class" do
      Restful.model_configuration_for(Foo.new).should == :foo_config
      Restful.model_configuration_for(FooBar.new).should == :foo_bar_config
    end

  end
end

require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

describe Restful do

  before(:each) do
    Restful.clear
  end

  it "should have a default_url_options accessor" do
    Restful.default_url_options.should == {}
  end

  it "should look up registered services" do
    Restful.register_web_service('foo')
    ws = Restful.web_service_configuration(:foo)
    ws.should_not be_nil
    ws.should be_kind_of(Restful::Configuration::WebService)
    ws.name.should == 'foo'
  end

  it "should lazily inject default_url_options into webservice configurations lacking it" do
    Restful.default_url_options = {:host => 'default-host.com'}
    Restful.register_web_service('foo')
    Restful.register_web_service('bar', :default_url_options => {:host => 'bar.com'})
    foo = Restful.web_service_configuration(:foo)
    foo.default_url_options.should == Restful.default_url_options
    foo.default_url_options.should_not equal(Restful.default_url_options)
    bar = Restful.web_service_configuration(:bar)
    bar.default_url_options.should == {:host => 'bar.com'}
  end

  it "should return nil if you request a web service that does not exist" do
    Restful.web_service_configuration(:does_not_exist)
  end

  it "should call web_service_configuration for nil key" do
    Restful.web_service_configuration(nil)
  end

  describe "single configuration" do
    before(:each) do
      configure_foo_service
    end

    it "should process a full configuration" do
      ws = Restful.web_service_configuration(:foo_web_service).to_hash(:ignore_empty => true)
      ws.should == {
        :api_prefix => "foo_api",
        :name => "Foo Web Service",
        :resources => {
          :bar => {
            :name_method => :name,
            :no_inherited_options => false,
            :shallow => false,
            :serialization => {
              :include => {:foo => {:only => [:column1]}},
              :only => [:id, :bar1, :bar2]
            },
            :url_for => nil,
            :associations => {:foo => nil}
          },
          :sub_bar1 => {
            :name_method => :name,
            :no_inherited_options => false,
            :shallow => false,
            :serialization => {
              :methods => [:interesting_state],
              :only => [:subbar1]
            },
            :url_for => nil,
          },
          :foo => {
            :name_method => :name,
            :no_inherited_options => false,
            :shallow => false,
            :serialization => {:only => [:id, :column1, :column2]},
            :url_for => nil,
            :associations => {:bars => nil}
          },
          :sub_bar2 => {
            :name_method => :name,
            :no_inherited_options => false,
            :shallow => false,
            :serialization => {:only => [:subbar1]},
            :url_for => nil,
          },
        },
      }
    end
  end

  describe "for multiple web services" do

    it "should allow multiple web services to be configured" do
      configure_foo_service
      configure_another_service
      Restful.registered_web_services.size.should == 2
      Restful.web_service_configuration(:another_service).resource_configuration_for(:another).to_hash(:ignore_empty => true).should == {
        :name_method => :name,
        :url_for => nil,
        :no_inherited_options => false,
        :shallow => false,
        :serialization => {
          :only => [:one, :two],
        },
      }
    end

  end

  def configure_another_service
    Restful.register_web_service(:another_service,
      :resources => {
        :another => {
          :serialization => {
            :only => [:one, :two],
          },
        }
      }
    ) 
  end

  def configure_foo_service
    Restful.register_web_service('Foo Web Service') do |config|
  
      config.api_prefix = 'foo_api'
  
      config.register_resource(:foo,
        :serialization => {
          :only => [:id, :column1, :column2],
        },
        :associations => {:bars => nil}
      )
  
      config.register_resource(:bar,
        :serialization => {
          :only => [:id, :bar1, :bar2],
          :include => {
            :foo => { :only => [:column1] }
          },
        },
        :associations => {:foo => nil}
      )
  
      config.register_resource(:sub_bar1) do |resource|
        resource.serialization do |serial|
          serial.only << :subbar1 
          serial.methods << :interesting_state
        end
      end
  
      config.register_resource(:sub_bar2) do |resource|
        resource.serialization do |serial|
          serial.only << :subbar1
        end
        resource.shallow = false
      end
    end
  end
end

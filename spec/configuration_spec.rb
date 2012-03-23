require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))

describe Restful::Configuration do

  describe "configurable equality" do
    class TestConfigurable
      include Restful::Configuration::Configurable
      option :name
      option :subs, :type => :hash, :element_type => 'SubConfigurable'
      option :defaulted, :default => :a_default

      # * :name
      # * :options => hash of options
      def initialize(*args)
        options = args.extract_options!
        super(options.merge(:name => args.shift))
      end
    end

    class SubConfigurable
      include Restful::Configuration::Configurable
      option :name
      option :stuff, :type => :array

      def initialize(*args)
        super(:name => args.shift, :stuff => args)
      end
      
    end

    before(:each) do
      @test = TestConfigurable.new(:test)
      @equal = TestConfigurable.new(:test)
      @different = TestConfigurable.new(:dif)
    end

    it "should be reflexive" do
      @test.should == @test
      @test.should equal(@test)
    end

    it "should be symetric" do
      @test.should == @equal
      @test.should_not equal(@equal)
      @equal.should == @test
      @equal.should_not equal(@test)
    end

    it "should handle inequality" do
      @test.should_not == @different
      @different.should_not == @test
    end

    it "should provide a hash" do
      @test.hash.should == @test.hash
      @test.hash.should == @equal.hash
      @test.hash.should_not == @different.hash
    end

    it "should convert to a hash" do
      @test.to_hash.should == {
        :name => :test,
        :subs => {},
        :defaulted => :a_default,
      }
    end

    it "should convert to a hash and skip empty containers" do
      @test.to_hash(:ignore_empty => true).should == {
        :name => :test,
        :defaulted => :a_default,
      }
    end

    it "should convert to a hash and skip defaulted values" do
      @test.to_hash(:skip_defaults => true).should == {
        :name => :test,
        :subs => {}, 
      }
    end
   
    it "should not skip options explicitly set to their default value" do
      @test.defaulted = :a_default
      @test.to_hash(:skip_defaults => true).should == {
        :subs => {}, 
        :name => :test,
        :defaulted => :a_default,
      }
      test2 = TestConfigurable.new(:test, :defaulted => :a_default)
      test2.to_hash(:skip_defaults => true).should == {
        :subs => {}, 
        :name => :test,
        :defaulted => :a_default,
      }
    end
 
    it "should convert to a hash and skip both" do
      @test.to_hash(:skip_defaults => true, :ignore_empty => true).should == {
        :name => :test,
      }
    end
  
    describe "with nested configurables" do
      before(:each) do
        @test = TestConfigurable.register(:test) do |conf|
          conf.subs[:sub1] = (@sub1 = SubConfigurable.new(:sub1, 1,2,3))
          conf.subs[:sub2] = (@sub2 = SubConfigurable.new(:sub2, 1,2,3))
          conf.subs[:sub3] = (@sub3 = SubConfigurable.new(:sub3, 4,5,6))
        end
        @equal = TestConfigurable.register(:test,
          :subs => {
            :sub1 => { :name => :sub1, :stuff => [1,2,3]},
            :sub2 => { :name => :sub2, :stuff => [1,2,3]},
            :sub3 => { :name => :sub3, :stuff => [4,5,6]},
          }
        )
        @different = TestConfigurable.register(:dif) do |conf|
          conf.subs[:difsub1] = (@difsub1 = SubConfigurable.new(:difsub1, 8,9,0))
          conf.subs[:sub2] = (@difsub2 = SubConfigurable.new(:sub2, 8,9,0))
        end
      end

      it "should still follow equality semantics" do
        @test.should == @test
        @test.should equal(@test)
        @test.should == @equal
        @test.should_not equal(@equal)
        @equal.should == @test
        @equal.should_not equal(@test)
        @test.should_not == @different
        @different.should_not == @test
        @test.hash.should == @test.hash
        @test.hash.should == @equal.hash
        @test.hash.should_not == @different.hash
      end

      it "should provide a deep clone" do
        clone = @test.deep_clone
        clone.should == @test
        clone.should == @equal
        clone.should_not equal(@test)
        clone.send(:config).should_not equal(@test.send(:config))
        clone.name = 'foo'
        @test.name.should_not == 'foo'
        clone.subs[:sub1].should == @sub1
        clone.subs[:sub1].name == 'bar'
        @sub1.name.should_not == 'bar' 
      end  
  
      it "should provide a deep merge" do
        merged = @test.deeper_merge!(@different)
        merged.name.should == @different.name
        merged.subs[:sub1].should == @sub1
        merged.subs[:sub2].stuff.should == @sub2.stuff + @difsub2.stuff
        merged.subs[:sub3].should == @sub3
        merged.subs[:difsub1].should == @difsub1
      end

      it "should raise errors if attempt to deep merge with different options" do
        @test.deeper_merge!(nil).should == @test
        lambda { @test.deeper_merge!(@sub1) }.should raise_error(ArgumentError)
        lambda { @test.deeper_merge!(:frotz => :spaniel) }.should raise_error(ArgumentError)
      end

    end
  end

  describe Restful::Configuration::Option do

    it "should construct an Option" do
      opt = Restful::Configuration::Option.new(:foo, :type => :array)
      opt.name.should == :foo
      opt.type.should == Array
    end

    it "should accept an element type parameter" do
      opt = Restful::Configuration::Option.new(:foo, :type => :array, :element_type => :symbol)
      opt.element_type.should == Symbol
    end
    
    it "should accept a default parameter" do
      opt = Restful::Configuration::Option.new(:foo, :default => false)
      opt.default.should == false 
    end

    it "should provide a new option instance" do
      opt = Restful::Configuration::Option.new(:foo, :type => :array)
      opt.initialized.should == []
    end

    it "should provide a new defaulted instance" do
      opt = Restful::Configuration::Option.new(:foo, :default => false)
      opt.initialized.should == false 
    end

    it "should provide nil for no type or default" do
      opt = Restful::Configuration::Option.new(:foo)
      opt.initialized.should be_nil
    end
  end

  describe Restful::Configuration::WebService do

    before(:each) do
      @ws = Restful::Configuration::WebService.new('Foo Service')
    end

    it "should construct a WebService configuration" do
      @ws.should be_kind_of(Restful::Configuration::WebService)
      @ws.name.should == 'Foo Service'
    end

    it "should initialize options" do
      @ws.api_prefix.should be_nil
      @ws.default_url_options.should == {}
      @ws.resources.should == {}
    end

    it "should allow resources to be registered" do
      @ws.register_resource(:gizmo, :url_for => 'the_gizmo') do |resource|
        resource.associations[:widget] = nil
      end
      (gizmo = @ws.resources[:gizmo]).should_not be_nil
      gizmo.url_for.should == 'the_gizmo'
      gizmo.associations.should == { :widget => nil }
    end

    it "should initialize from a hash" do
      ws = Restful::Configuration::WebService.new(:a_service,
        :api_prefix => 'prefix',
        :default_url_options => {:host => 'the_host.com'},
        :resources => { 
          :r1 => {
            :serialization => {
              :only => :id
            }
          }
        }
      )
      ws.api_prefix.should == 'prefix'
      ws.resources.size.should == 1
      ws.to_hash(:ignore_empty => true).should == {
        :name => :a_service,
        :api_prefix => 'prefix',
        :default_url_options => {:host => 'the_host.com'},
        :resources => {
          :r1 => {
            :name_method => :name,
            :url_for => nil,
            :no_inherited_options => false,
            :shallow => false,
            :serialization => {
              :only => [:id]
            },
          },
        },
      }
    end

    it "should automatically symbolize keys" do
      ws = Restful::Configuration::WebService.new('a service',
        'api_prefix' => 'prefix',
        'default_url_options' => { 'host' => 'a_host.com'}
      )
      ws.api_prefix.should == 'prefix'
      ws.default_url_options == { 'host' => 'bar' }
      ws.to_hash(:ignore_empty => true).should == {
        :name => 'a service',
        :api_prefix => 'prefix',
        :default_url_options => { :host => 'a_host.com'},
      }
    end

    it "should convert to a hash of web service configuration" do
      @ws.to_hash.should == {
        :name => 'Foo Service',
        :api_prefix => nil,
        :default_url_options => {},
        :resources => {},
      }
      @ws.register_resource(:gizmo, :url_for => 'the_gizmo') do |resource|
        resource.associations[:widget] = nil
      end
      (config_hash = @ws.to_hash).should == {
        :name => 'Foo Service',
        :api_prefix => nil,
        :default_url_options => {},
        :resources => {
          :gizmo => {
            :name_method => :name,
            :url_for => 'the_gizmo',
            :associations => { :widget => nil },
            :serialization => {
              :only => [],
              :except => [],
              :methods => [],
              :include => {},
            },
            :no_inherited_options => false,
            :shallow => false,
          },
        },
      }
      @ws.resources.should_not equal(config_hash[:resources])
      @ws.resources[:gizmo].serialization.should_not equal(config_hash[:resources][:gizmo][:serialization])
      @ws.resources[:gizmo].serialization.only.should_not equal(config_hash[:resources][:gizmo][:serialization][:only])

      @ws.to_hash(:ignore_empty => true).should == {
        :name => 'Foo Service',
        :api_prefix => nil,
        :resources => {
          :gizmo => {
            :name_method => :name,
            :url_for => 'the_gizmo',
            :associations => { :widget => nil },
            :no_inherited_options => false,
            :shallow => false,
          },
        },
      }
    end
  end

  describe Restful::Configuration::Resource do
    
    before(:each) do
      @res = Restful::Configuration::Resource.new()
    end

    it "should construct a Resource configuration" do
      @res.should be_kind_of(Restful::Configuration::Resource)
    end

    it "should initialize options" do
      @res.url_for.should be_nil
      @res.associations.should == {}
      @res.serialization.should be_kind_of(Restful::Configuration::ARSerialization)
      @res.no_inherited_options.should == false 
      @res.shallow.should == false
    end

    it "should allow serialization to be configured by a block" do
      @res.serialization do |serial|
        serial.only = [:foo, :bar]
      end
      @res.serialization.only.should == [:foo, :bar]
    end

    it "should convert to a hash of resource configuration" do
      @res.to_hash.should == {
        :name_method => :name,
        :url_for => nil,
        :associations => {},
        :serialization => {
          :only => [],
          :except => [],
          :methods => [],
          :include => {},
        },
        :no_inherited_options => false,
        :shallow => false,
      }
    end

    it "should automatically symbolize keys" do
      res = Restful::Configuration::Resource.new(
        'url_for' => 'biscuit',
        'associations' => { 'bob' => 'bobby' },
        'shallow' => true
      )
      res.url_for.should == 'biscuit'
      res.associations.should == { :bob => 'bobby' }
      res.shallow.should == true
      res.to_hash(:ignore_empty => true).should == {
        :name_method => :name,
        :url_for => 'biscuit',
        :associations => { :bob => 'bobby' },
        :no_inherited_options => false,
        :shallow => true,
      }
    end

    it "should convert to a hash of resource configuration ignoring empty containers" do
      @res.to_hash(:ignore_empty => true).should == {
        :name_method => :name,
        :url_for => nil,
        :no_inherited_options => false,
        :shallow => false,
      }
    end
  end

  describe Restful::Configuration::ARSerialization do

    before(:each) do
      @ars = Restful::Configuration::ARSerialization.new
    end

    it "should construct an ARSerialization configuration" do
      @ars.should be_kind_of(Restful::Configuration::ARSerialization)
      @ars.should be_kind_of(Restful::Configuration::Configurator)
      @ars.class.should respond_to(:register)
    end

    it "should initialize attribute structures" do
      @ars.only.should == []
      @ars.except.should == []
      @ars.methods.should == []
      @ars.include.should == {} 
    end

    it "should initialize from a hash" do
      ars = Restful::Configuration::ARSerialization.new(
        :only => [:foo, :bar],
        :methods => :bob
      )
      ars.only.should == [:foo, :bar]
      ars.methods.should == [:bob]
      ars.to_hash(:ignore_empty => true).should == {
        :only => [:foo, :bar],
        :methods => [:bob],
      }
    end

    it "should allow included arserializations" do
      @ars.includes(:another) do |serial|
        serial.only = [:foo, :bar]
      end
      (inc = @ars.include[:another]).should_not be_nil
      inc.only.should == [:foo, :bar]
    end

    it "should allow deeply nested included arserializations" do
      @ars.includes(:another) do |serial|
        serial.only = [:foo, :bar]
        serial.includes(:leaf) do |leaf_serial|
          leaf_serial.except << :not_me
        end
      end
      (inc = @ars.include[:another]).should_not be_nil
      inc.only.should == [:foo, :bar]
      (leaf = inc.include[:leaf]).should_not be_nil
      leaf.except.should == [:not_me]
    end

    it "should convert to a hash" do
      @ars.to_hash.should == {
        :only => [],
        :except => [],
        :methods => [],
        :include => {}
      }
      @ars = Restful::Configuration::ARSerialization.register do |serial|
        serial.only = [:foo, :bar]
        serial.includes(:another) do |inc|
          inc.except << :not_me
        end
      end
      @ars.to_hash.should == {
        :only => [:foo, :bar],
        :except => [],
        :methods => [],
        :include => {
          :another => {
            :only => [],
            :except => [:not_me],
            :methods => [],
            :include => {},
          },
        },
      }
    end

    it "should convert to a hash, ignoring options with empty containers" do
      @ars.to_hash(:ignore_empty => true).should == { }
      @ars = Restful::Configuration::ARSerialization.register do |serial|
        serial.only = [:foo, :bar]
        serial.includes(:another) do |inc|
          inc.except << :not_me
        end
      end
      @ars.to_hash(:ignore_empty => true).should == {
        :only => [:foo, :bar],
        :include => {
          :another => {
            :except => [:not_me],
          },
        },
      }

    end
  end

end

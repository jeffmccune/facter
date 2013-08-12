#! /usr/bin/env ruby

require 'spec_helper'
require 'facter/util/gce'

describe "gce facts" do
  # This is the standard prefix for making an API call in GCE (or fake)
  # environments.
  let(:api_prefix) { "http://metadata/computeMetadata" }
  let(:api_version) { "v1beta1" }

  describe "when running on gce" do
    before :each do
      # Assume we can connect
      Facter::Util::GCE.stubs(:can_connect?).returns(true)
      Facter::Util::GCE.stubs(:read_uri).
        with('http://metadata').returns('OK')
      Facter.stubs(:value).
        with('virtual').returns('gce')
    end

    let :util do
      Facter::Util::GCE
    end

    it "defines facts dynamically from metadata/" do
      util.stubs(:read_uri).
        with("#{api_prefix}/#{api_version}/").
        returns("some_key_name")
      util.stubs(:read_uri).
        with("#{api_prefix}/#{api_version}/some_key_name").
        at_least_once.returns("some_key_value")

      Facter::Util::GCE.add_gce_facts(:force => true)

      Facter.fact(:gce_some_key_name).
        value.should == "some_key_value"
    end

    it "should create structured metadata facts" do
      util.stubs(:read_uri).
        with("#{api_prefix}/#{api_version}/").
        returns("foo/")
      util.stubs(:read_uri).
        with("#{api_prefix}/#{api_version}/foo/").
        at_least_once.returns("bar")
      util.stubs(:read_uri).
        with("#{api_prefix}/#{api_version}/foo/bar").
        at_least_once.returns("baz")

      Facter::Util::GCE.add_gce_facts(:force => true)

      Facter.fact(:gce_foo_bar).value.should == "baz"
    end

  end
end

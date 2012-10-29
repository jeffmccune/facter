#! /usr/bin/env ruby

require 'spec_helper'
require 'facter/util/ec2'

describe "ec2 facts" do
  # This is the standard prefix for making an API call in EC2 (or fake)
  # environments.
  let(:api_prefix) { "http://169.254.169.254" }

  subject do
    Facter::Util::EC2.new
  end

  before :each do
    # Prevent loading the fact file from trying to talk to the EC2 API.
    # We explicitly call addfacts in the examples.
    Facter::Util::EC2.stubs(:addfacts)
  end

  describe "when running on ec2" do
    before :each do
      subject.stubs(:has_ec2_arp?).returns(true)
      subject.stubs(:can_connect?).returns(true)
      subject.stubs(:has_euca_mac?).returns(false)
      subject.stubs(:has_openstack_mac?).returns(false)
    end

    describe "automatically generated facts" do
      it "should create flat meta-data facts" do
        subject.stubs(:open).
          with("#{api_prefix}/2008-02-01/meta-data/").at_least_once.
          returns(StringIO.new("user_defined_key"))
        subject.stubs(:open).
          with("#{api_prefix}/2008-02-01/meta-data/user_defined_key").at_least_once.
          returns(StringIO.new("user_defined_value"))

        subject.stubs(:add_userdata_facts)

        Facter.collection.loader.load(:ec2)
        Facter.fact(:ec2_user_defined_key).value.should == "user_defined_value"
      end
    end


    it "should create flat meta-data facts with comma seperation" do
      Object.any_instance.expects(:open).
        with("#{api_prefix}/2008-02-01/meta-data/").
        at_least_once.returns(StringIO.new("foo"))

      Object.any_instance.expects(:open).
        with("#{api_prefix}/2008-02-01/meta-data/foo").
        at_least_once.returns(StringIO.new("bar\nbaz"))

      # No user-data
      Object.any_instance.expects(:open).
        with("#{api_prefix}/2008-02-01/user-data/").
        at_least_once.returns(StringIO.new(""))

      Facter.collection.loader.load(:ec2)
      Facter.fact(:ec2_foo).value.should == "bar,baz"
    end

    it "should create structured meta-data facts" do
      Object.any_instance.expects(:open).
        with("#{api_prefix}/2008-02-01/meta-data/").
        at_least_once.returns(StringIO.new("foo/"))

      Object.any_instance.expects(:open).
        with("#{api_prefix}/2008-02-01/meta-data/foo/").
        at_least_once.returns(StringIO.new("bar"))

      Object.any_instance.expects(:open).
        with("#{api_prefix}/2008-02-01/meta-data/foo/bar").
        at_least_once.returns(StringIO.new("baz"))

      # No user-data
      Object.any_instance.expects(:open).
        with("#{api_prefix}/2008-02-01/user-data/").
        at_least_once.returns(StringIO.new(""))

      Facter.collection.loader.load(:ec2)
      Facter.fact(:ec2_foo_bar).value.should == "baz"
    end

    it "should create ec2_user_data fact" do
      # No meta-data
      Object.any_instance.expects(:open).
        with("#{api_prefix}/2008-02-01/meta-data/").
        at_least_once.returns(StringIO.new(""))

      Object.any_instance.expects(:open).
        with("#{api_prefix}/2008-02-01/user-data/").
        at_least_once.returns(StringIO.new("test"))

      Facter.collection.loader.load(:ec2)
      Facter.fact(:ec2_userdata).value.should == ["test"]
    end
  end

  describe "when running on eucalyptus" do
    before :each do
      # Return false for ec2, true for eucalyptus
      Facter::Util::EC2.stubs(:has_euca_mac?).returns(true)
      Facter::Util::EC2.stubs(:has_openstack_mac?).returns(false)
      Facter::Util::EC2.stubs(:has_ec2_arp?).returns(false)

      # Assume we can connect
      Facter::Util::EC2.stubs(:can_connect?).returns(true)
    end

    it "should create ec2_user_data fact" do
      # No meta-data
      Object.any_instance.expects(:open).\
        with("#{api_prefix}/2008-02-01/meta-data/").\
        at_least_once.returns(StringIO.new(""))

      Object.any_instance.expects(:open).\
        with("#{api_prefix}/2008-02-01/user-data/").\
        at_least_once.returns(StringIO.new("test"))

      # Force a fact load
      Facter.collection.loader.load(:ec2)

      Facter.fact(:ec2_userdata).value.should == ["test"]
    end
  end

  describe "when running on openstack" do
    before :each do
      # Return false for ec2, true for eucalyptus
      Facter::Util::EC2.stubs(:has_openstack_mac?).returns(true)
      Facter::Util::EC2.stubs(:has_euca_mac?).returns(false)
      Facter::Util::EC2.stubs(:has_ec2_arp?).returns(false)

      # Assume we can connect
      Facter::Util::EC2.stubs(:can_connect?).returns(true)
    end

    it "should create ec2_user_data fact" do
      # No meta-data
      Object.any_instance.expects(:open).\
        with("#{api_prefix}/2008-02-01/meta-data/").\
        at_least_once.returns(StringIO.new(""))

      Object.any_instance.expects(:open).\
        with("#{api_prefix}/2008-02-01/user-data/").\
        at_least_once.returns(StringIO.new("test"))

      # Force a fact load
      Facter.collection.loader.load(:ec2)

      Facter.fact(:ec2_userdata).value.should == ["test"]
    end
  end

  describe "when api connect test fails" do
    it "should not populate ec2_userdata" do
      # Emulate ec2 for now as it matters little to this test
      Facter::Util::EC2.stubs(:has_euca_mac?).returns(true)
      Facter::Util::EC2.stubs(:has_ec2_arp?).never
      Facter::Util::EC2.expects(:can_connect?).at_least_once.returns(false)

      # The API should never be called at this point
      Object.any_instance.expects(:open).
        with("#{api_prefix}/2008-02-01/meta-data/").never
      Object.any_instance.expects(:open).
        with("#{api_prefix}/2008-02-01/user-data/").never

      # Force a fact load
      Facter.collection.loader.load(:ec2)

      Facter.fact(:ec2_userdata).should == nil
    end
  end
end

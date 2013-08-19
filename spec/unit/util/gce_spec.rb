#! /usr/bin/env ruby

require 'spec_helper'
require 'facter/util/gce'

describe Facter::Util::GCE do
  let(:api_version) { "v1beta1" }

  describe "Facter::Util::GCE.with_metadata_server" do
    before :each do
      Facter::Util::GCE.stubs(:read_uri).returns(api_version)
    end

    subject do
      Facter::Util::GCE.with_metadata_server do
        "HELLO FROM THE CODE BLOCK"
      end
    end

    context 'Running in a VMware Virtual Machine (Outside of GCE)' do
      before :each do
        Facter.stubs(:value).with('virtual').returns('vmware')
      end
      it 'returns false when not running on gce' do
        subject.should be_false
      end
      it 'does not try to connect to the metadata service' do
        described_class.expects(:read_uri).never
        subject.should be_false
      end
    end

    context 'Running in a Google Compute Engine instance' do
      before :each do
        Facter.stubs(:value).with('virtual').returns('gce')
      end
      it 'returns the value of the block when the metadata server responds' do
        subject.should == "HELLO FROM THE CODE BLOCK"
      end
      it 'returns false when the metadata server is unreachable' do
        described_class.stubs(:read_uri).raises(Errno::ENETUNREACH)
        subject.should be_false
      end
      it 'does not execute the block if the connection raises an exception' do
        described_class.stubs(:read_uri).raises(Timeout::Error)
        myvar = "The block didn't get called"
        described_class.with_metadata_server do
          myvar = "The block was called and should not have been."
        end.should be_false
        myvar.should == "The block didn't get called"
      end
      it 'succeeds on the third retry' do
        retry_metadata = sequence('metadata')
        Timeout.expects(:timeout).twice.in_sequence(retry_metadata).raises(Timeout::Error)
        Timeout.expects(:timeout).once.in_sequence(retry_metadata).returns(true)
        subject.should == "HELLO FROM THE CODE BLOCK"
      end
    end
  end

  describe "Facter::Util::GCE.add_gce_facts" do
    GCE_METADATA_JSON = File.read(fixtures('unit/util/gce', 'gce_metadata_example.json'))

    let(:metadata_root) { %w{ 0.1/ computeMetadata/ }.join("\n") }
    let(:metadata_json) { GCE_METADATA_JSON }

    before :each do
      described_class.instance_variable_set(:@add_gce_facts_has_run, nil)
      Facter.stubs(:value).with('virtual').returns('gce')
      # Stub the initial call in with_metadata_server()
      described_class.stubs(:read_uri).
        with('http://metadata').
        returns(metadata_root)
      # Stub the JSON response in gather_metadata()
      described_class.stubs(:read_uri).
        with('http://metadata/computeMetadata/v1beta1/?recursive=true&alt=json').
        returns(metadata_json)
    end

    context 'with default options' do
      it 'gathers facts the first time it is invoked' do
        described_class.expects(:gather_metadata).once
        described_class.add_gce_facts
      end

      it 'does not gather facts after the first invocation' do
        described_class.expects(:gather_metadata).once
        2.times do
          described_class.add_gce_facts
        end
      end

      it 'returns nil if facts have already been gathered' do
        described_class.add_gce_facts
        described_class.add_gce_facts.should be_nil
      end

      it 'defines the gce_instance_description fact' do
        described_class.add_gce_facts
        Facter.fact(:gce_instance_description).value.should eq("System to test Facter")
      end

      it 'defines the gce_instance_disks_0_deviceName fact' do
        described_class.add_gce_facts
        Facter.fact(:gce_instance_disks_0_deviceName).value.should eq("facter1")
      end

      it 'defines the gce_instance_disks_0_index fact' do
        described_class.add_gce_facts
        Facter.fact(:gce_instance_disks_0_index).value.should eq(0)
      end

      it 'defines the gce_instance_disks_0_mode fact' do
        described_class.add_gce_facts
        Facter.fact(:gce_instance_disks_0_mode).value.should eq("READ_WRITE")
      end

      it 'defines the gce_instance_disks_0_type fact' do
        described_class.add_gce_facts
        Facter.fact(:gce_instance_disks_0_type).value.should eq("PERSISTENT")
      end

      it 'defines the gce_instance_hostname fact' do
        described_class.add_gce_facts
        Facter.fact(:gce_instance_hostname).value.should eq("facter1.c.jeff-fog.puppetlabs.com.internal")
      end

      it 'defines the gce_instance_id fact' do
        described_class.add_gce_facts
        Facter.fact(:gce_instance_id).value.should eq(5332037549869110855)
      end

      it 'defines the gce_instance_image fact' do
        described_class.add_gce_facts
        Facter.fact(:gce_instance_image).value.should be_nil
      end

      it 'defines the gce_instance_machineType fact' do
        described_class.add_gce_facts
        Facter.fact(:gce_instance_machineType).value.should eq("n1-highcpu-8")
      end

      it 'defines the gce_instance_networkInterfaces_0_accessConfigs_0_externalIp fact' do
        described_class.add_gce_facts
        Facter.fact(:gce_instance_networkInterfaces_0_accessConfigs_0_externalIp).value.
          should eq("173.255.115.92")
      end

      it 'defines the gce_instance_networkInterfaces_0_accessConfigs_0_type fact' do
        described_class.add_gce_facts
        Facter.fact(:gce_instance_networkInterfaces_0_accessConfigs_0_type).value.
          should eq("ONE_TO_ONE_NAT")
      end

      it 'defines the gce_instance_networkInterfaces_0_ip fact' do
        described_class.add_gce_facts
        Facter.fact(:gce_instance_networkInterfaces_0_ip).value.
          should eq("10.211.244.148")
      end

      it 'defines the gce_instance_networkInterfaces_0_network fact' do
        described_class.add_gce_facts
        Facter.fact(:gce_instance_networkInterfaces_0_network).value.
          should eq("default")
      end

      it 'defines the gce_instance_serviceAccounts_3867bsu2.default@developer.gserviceaccount.com_aliases_0 fact' do
        described_class.add_gce_facts
        Facter.fact(:"gce_instance_serviceAccounts_3867bsu2.default@developer.gserviceaccount.com_aliases_0").
          value.should eq("default")
      end

      it 'defines the gce_instance_serviceAccounts_3867bsu2.default@developer.gserviceaccount.com_email fact' do
        described_class.add_gce_facts
        Facter.fact(:"gce_instance_serviceAccounts_3867bsu2.default@developer.gserviceaccount.com_email").
          value.should eq("3867bsu2.default@developer.gserviceaccount.com")
      end

      it 'defines the gce_instance_serviceAccounts_3867bsu2.default@developer.gserviceaccount.com_scopes_0 fact' do
        described_class.add_gce_facts
        Facter.fact(:"gce_instance_serviceAccounts_3867bsu2.default@developer.gserviceaccount.com_scopes_0").
          value.should eq("https://www.googleapis.com/auth/compute")
      end

      it 'defines the gce_instance_serviceAccounts_3867bsu2.default@developer.gserviceaccount.com_scopes_1 fact' do
        described_class.add_gce_facts
        Facter.fact(:"gce_instance_serviceAccounts_3867bsu2.default@developer.gserviceaccount.com_scopes_1").
          value.should eq("https://www.googleapis.com/auth/devstorage.full_control")
      end

      it 'defines the gce_instance_zone fact' do
        described_class.add_gce_facts
        Facter.fact(:gce_instance_zone).value.should eq("us-central1-b")
      end

      it 'defines the gce_project_numericProjectId fact' do
        described_class.add_gce_facts
        Facter.fact(:gce_project_numericProjectId).value.should eq(111878206402)
      end

      it 'defines the gce_project_projectId fact' do
        described_class.add_gce_facts
        Facter.fact(:gce_project_projectId).value.should eq("puppetlabs.com:jeff-fog")
      end
    end
  end
end

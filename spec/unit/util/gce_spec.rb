#! /usr/bin/env ruby

require 'spec_helper'
require 'facter/util/gce'

describe Facter::Util::GCE do
  # This is the standard prefix for making an API call in GCE (or fake)
  # environments.
  let(:api_prefix) { "http://metadata/computeMetadata" }
  let(:api_version) { "v1beta1" }

  describe "Facter::Util::GCE.with_metadata_server", :focus => true do
    before :each do
      Facter::Util::GCE.stubs(:read_uri).returns(:api_version)
    end

    subject do
      Facter::Util::GCE.with_metadata_server do
        "HELLO FROM THE CODE BLOCK"
      end
    end

    it 'returns false when not running on gce' do
      Facter.stubs(:value).with('virtual').returns('vmware')
      subject.should be_false
    end

    context 'default options and running on a gce virtual machine' do
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
end

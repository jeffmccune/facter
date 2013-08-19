# Copyright 2013 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Google Compute Engine: Storing and Retrieving Metadata
# https://developers.google.com/compute/docs/metadata

# TL;DR
# From the GCE instance, collect all facts about the GCE instance and project
# with 'curl "http://metadata/computeMetadata/v1beta1/?recursive=true&alt=json'

require 'timeout'
require 'open-uri'
require 'json'

# Provide a set of utility static methods that help with resolving the GCE
# fact.
module Facter::Util::GCE
  CONNECTION_ERRORS = [
    OpenURI::HTTPError,
    Errno::EHOSTDOWN,
    Errno::EHOSTUNREACH,
    Errno::ENETUNREACH,
    Errno::ECONNABORTED,
    Errno::ECONNREFUSED,
    Errno::ECONNRESET,
    Errno::ETIMEDOUT,
  ]

  METADATA_SERVER_URL="http://metadata/computeMetadata/v1beta1/"

  def self.metadata_facts(var, val)
    if val.is_a?(Hash)
      val.each_pair do |k, v|
        if ["machineType", "zone", "network"].include? k
          v = v.split('/')[-1]
        end
        metadata_facts("#{var}_#{k}", v)
      end
    elsif val.is_a?(Array)
      val.each_with_index do |v, i|
        metadata_facts("#{var}_#{i}", v)
      end
    else
      # convert the sshKeys single entry into multiple entries, one
      # per key
      if var.end_with? "sshKeys"
        val.split("\n").each_with_index do |v, i|
          Facter.add("#{var}_#{i}".to_sym) { setcode { v } }
        end
      else
        Facter.add(var.to_sym) { setcode { val } }
      end
    end
  end

  ##
  # uses the metadata server's recursive/json feature to pull all
  # data in a single request
  def self.gather_metadata
    begin
      if body = read_uri("#{METADATA_SERVER_URL}?recursive=true&alt=json")
        metadata_facts('gce', JSON.parse(body))
      end
    rescue *CONNECTION_ERRORS => detail
      Facter.warn "Could not retrieve gce metadata: #{detail.message}"
    end
  end

  ##
  # with_metadata_server takes a block of code and executes the block only if
  # Facter is running on node that can access a metadata server at
  # http://metadata/.  This is useful to decide if it's reasonably
  # likely that talking to the GCE metadata server will be successful or not.
  #
  # @option options [Integer] :timeout (100) the maxiumum number of
  # milliseconds Facter will block trying to talk to the metadata server.
  # Defaults to 200.
  #
  # @option options [String] :fact ('virtual') the fact to check.  The block
  # will only be executed if the fact named here matches the value named in the
  # :value option.
  #
  # @option options [String] :value ('gce') the value to check.  The block
  # will be executed if Facter.value(options[:fact]) matches this value.
  #
  # @option options [Fixnum] :retry_limit (3) the maximum number of times that
  # this method will try to contact the metadata server.  The maximum run time
  # is the timeout times this limit, so please keep the value small.
  #
  # @return [Object] the return value of the passed block, or {false} if the
  # block was not executed because the conditions were not met or a timeout
  # occurs.
  def self.with_metadata_server(options = {}, &block)
    opts = options.dup
    opts[:timeout] ||= 100
    opts[:fact] ||= 'virtual'
    opts[:value] ||= 'gce'
    opts[:retry_limit] ||= 3
    # Conversion to fractional seconds for Timeout
    timeout = opts[:timeout] / 1000.0
    raise ArgumentError, "A value is required for :fact" if opts[:fact].nil?
    raise ArgumentError, "A value is required for :value" if opts[:value].nil?
    return false if Facter.value(opts[:fact]) != opts[:value]

    metadata_base_url = "http://metadata"

    attempts = 0
    begin
      able_to_connect = false
      attempts = attempts + 1
      # Read the list of supported API versions
      Timeout.timeout(timeout) do
        read_uri(metadata_base_url)
      end
    rescue Timeout::Error => detail
      retry if attempts < opts[:retry_limit]
      Facter.warn "Timeout exceeded trying to communicate with #{metadata_base_url}, " +
        "metadata server facts will be undefined. #{detail.message}"
    rescue Errno::EHOSTUNREACH, Errno::ENETUNREACH, Errno::ECONNREFUSED => detail
      retry if attempts < opts[:retry_limit]
      Facter.warn "No metadata server available at #{metadata_base_url}, " +
        "metadata server facts will be undefined. #{detail.message}"
    rescue OpenURI::HTTPError => detail
      retry if attempts < opts[:retry_limit]
      Facter.warn "Metadata server at #{metadata_base_url} responded with an error. " +
        "metadata server facts will be undefined. #{detail.message}"
    else
      able_to_connect = true
    end

    if able_to_connect
      return block.call
    else
      return false
    end
  end

  ##
  # read_uri provides a seam method to easily test the HTTP client
  # functionality of a HTTP based metadata server.
  #
  # @api private
  #
  # @return [String] containing the body of the response
  def self.read_uri(uri)
    open(uri).read
  end
  private_class_method :read_uri

  ##
  # add_gce_facts defines GCE related facts when running on an GCE compatible
  # node.  This method will only ever do work once for the life of a process in
  # order to limit the amount of network I/O.
  #
  # @option options [Boolean] :force (false) whether or not to force
  # re-definition of the facts.
  def self.add_gce_facts(options = {})
    opts = options.dup
    opts[:force] ||= false
    unless opts[:force]
      return nil if @add_gce_facts_has_run
    end
    @add_gce_facts_has_run = true
    with_metadata_server :timeout => 50 do
      gather_metadata
    end
  end
end

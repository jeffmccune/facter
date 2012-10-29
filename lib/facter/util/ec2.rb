require 'open-uri'

module Facter
module Util
##
# The EC2 class is meant to contain all of the data and behavior required to
# add EC2 specific facts and their values to Facter.
#
# Usage:
#
# `Facter::EC2.new.addfacts`
class EC2
  ##
  # Facter::EC2.addfacts is meant to be a thin wrapper around the addfacts
  # instance method.  This class method is intended to make it easier to load
  # this file into a test harness without also causing the knock on side effect
  # of actually adding the facts to the system.
  def self.addfacts
    new.addfacts
  end

  ##
  # addfacts is responsible for adding the EC2 specific facts and their values.
  # The intent of this instance method 
  def addfacts
    if has_euca_mac? || has_openstack_mac? || has_ec2_arp? && can_connect?
      puts Time.now
      add_metadata_facts
      puts Time.now
      add_userdata_facts
    else
      Facter.debug "Not an EC2 host"
    end
  end

  def add_metadata_facts(id = "")
    binding.pry
    if keys = list_keys

    end

    open("http://169.254.169.254/2008-02-01/meta-data/#{id||=''}").read.split("\n").each do |o|
      key = "#{id}#{o.gsub(/\=.*$/, '/')}"
      if key[-1..-1] != '/'
        value = open("http://169.254.169.254/2008-02-01/meta-data/#{key}").read.split("\n")
        symbol = "ec2_#{key.gsub(/\-|\//, '_')}".to_sym
        Facter.add(symbol) { setcode { value.join(',') } }
      else
        add_metadata_facts(key)
      end
    end
  end

  def add_userdata_facts
    begin
      value = open("http://169.254.169.254/2008-02-01/user-data/").read.split
      Facter.add(:ec2_userdata) { setcode { value } }
    rescue OpenURI::HTTPError
    end
  end

  ##
  # Test if we can connect to the EC2 api. Return true if able to connect.
  # On failure this function fails silently and returns false.
  #
  # The +wait_sec+ parameter provides you with an adjustable timeout.
  #
  # @return [Boolean] true if there is a response from the API
  def can_connect?(wait_sec=2)
    url = "http://169.254.169.254:80/"
    Timeout::timeout(wait_sec) {open(url)}
    return true
    rescue Timeout::Error
      return false
    rescue
      return false
  end


  ##
  # Test if this host has a mac address used by Eucalyptus clouds, which
  # normally is +d0:0d+.
  #
  # @return [Boolean] true if the node has an Eucalyptus MAC address, false
  # otherwise
  def has_euca_mac?
    !! (/^D0:0D/i).match(Facter.value(:macaddress))
  end

  ##
  # Test if this host has a mac address used by OpenStack, which
  # normally starts with FA:16:3E (older versions of OpenStack
  # may generate mac addresses starting with 02:16:3E)
  # 
  # @return [Boolean] true if the node has an OpenStack MAC address, false
  # otherwise
  def has_openstack_mac?
    !! (/^(02|FA):16:3E/i).match(Facter.value(:macaddress))
  end

  ##
  # has_ec2_arp? tests if the host has an arp entry in its cache that matches
  # the EC2 arp, which is normally +fe:ff:ff:ff:ff:ff+.
  #
  # @return [Boolean] true if the machine has an entry in the arp cache
  # matching the EC2 environment.
  def has_ec2_arp?
    mac_address = case Facter.value(:kernel)
                  when /Windows/i
                    "fe-ff-ff-ff-ff-ff"
                  else
                    "fe:ff:ff:ff:ff:ff"
                  end
    command = case Facter.value(:kernel)
              when /Windows/i
                "arp -a"
              else
                "arp -an"
              end

    if arp_table = arp(command) then
      arp_table.each_line do |line|
        return true if line.downcase.include?(mac_address)
      end
    end
    false
  end

  ##
  # arp is intended to break the dependency between instances of this class and
  # the entire resolution system.  This method is intended to make it easier to
  # mock the system in spec tests.
  def arp(command)
    Facter::Util::Resolution.exec(command)
  end
  private :arp

  ##
  # open is intended to break the dependency on File.open and avoid the need to
  # do something like `Object.any_instance.expects(:open)` which changes way
  # too much behavior through the entire system.
  #
  # @return [String] the content of the resource at the URI
  def open(uri)
    Kernel.open(uri)
  end
  private :open

  ##
  # list_keys is intended to list all of the meta-data keys that should have
  # facts created.
  #
  # @return [Array] containing the meta-data keys
  def list_keys
    return_list = Array.new
    open("http://169.254.169.254/2008-02-01/meta-data/").read.split("\n").each do |line|
      key = line.gsub(/\=.*$/, '/'
      if key[-1..-1] != '/'
        value = open("http://169.254.169.254/2008-02-01/meta-data/#{key}").read.split("\n")
        symbol = "ec2_#{key.gsub(/\-|\//, '_')}".to_sym
        Facter.add(symbol) { setcode { value.join(',') } }
      else

  end
  private :list_keys
end
end
end

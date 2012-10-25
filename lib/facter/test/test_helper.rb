module Facter
module Test
  ##
  # TestHelper is intended to provide an API to be used by external projects
  #  when they are running tests that depend on facter core.  This should
  #  allow us to vary the implementation details of managing facter's state
  #  for testing, from one version of facter to the next--without forcing
  #  the external projects to do any of that state management or be aware of
  #  the implementation details.
  #
  # This class is a fairly straightforward copy of Puppet::Test::TestHelper
  #
  # For now, this consists of a few very simple signatures.  The plan is
  #  that it should be the responsibility of the facterlabs_spec_helper
  #  to broker between external projects and this API; thus, if any
  #  hacks are required (e.g. to determine whether or not a particular)
  #  version of facter supports this API, those hacks will be consolidated in
  #  one place and won't need to be duplicated in every external project.
  #
  # This should also alleviate the anti-pattern that we've been following,
  #  wherein each external project starts off with a copy of facter core's
  #  test_helper.rb and is exposed to risk of that code getting out of
  #  sync with core.
  #
  # Since this class will be "library code" that ships with facter, it does
  #  not use API from any existing test framework such as rspec.  This should
  #  theoretically allow it to be used with other unit test frameworks in the
  #  future, if desired.
  #
  # Note that in the future this API could potentially be expanded to handle
  #  other features such as "around_test", but we didn't see a compelling
  #  reason to deal with that right now.
  class TestHelper
    ##
    # Call before_all_tests once before an example group runs any examples.
    # @return nil
    def self.before_all_tests

    end

    ##
    # Call after_all_tests once, at the end of an example group.
    # @return nil
    def self.after_all_tests

    end

    ##
    # Call before_each_test once per test, before execution of an example.
    def self.before_each_test
      Facter::Util::Loader.any_instance.stubs(:load_all)
      Facter.clear
      Facter.clear_messages
      Facter.collection.loader.load(:pe_version)
    end

    ##
    # Call after_each_test once per test, after execution of an example.
    # @return nil
    def self.after_each_test

    end
  end
end
end

require 'coveralls'
Coveralls.wear!

require 'rbuv'

# This file was generated by the `rspec --init` command. Conventionally, all
# specs live under a `spec` directory, which RSpec adds to the `$LOAD_PATH`.
# Require this file using `require "spec_helper"` to ensure that it is only
# loaded once.
#
# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
module Helpers
  def it_raise_error_when_closed
    method = /^#([a-zA-Z][a-zA-Z0-9]*[\?\!]?)$/.match(description)[1]
    context "when handle is closed" do
      around do |example|
        subject.close do
          example.run
        end
        loop.run
      end

      it "raise Rbuv::Error" do
        expect {
          subject.__send__(method)
        }.to raise_error Rbuv::Error, "This #{subject.class} handle is closed"
      end
    end
  end

  def it_requires_a_block(*args)
    method = /^#([a-zA-Z][a-zA-Z0-9]*[\?\!]?)$/.match(description)[1]

    it "requires a block" do
      expect {
        subject.__send__(method, *args)
      }.to raise_error LocalJumpError, 'no block given'
    end
  end
end
RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = 'random'
  config.extend Helpers
end

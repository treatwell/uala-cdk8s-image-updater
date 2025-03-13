module RSpec
  module StubbedEnvHelpers
    # Helpers to unobtrusively stub ENV
    # Can be called with all key value pairs to be stubbed as a hash:
    #
    #     stub_env('A' => 'B', 'C' => 'D', 'E' => 'F')
    #
    # Alternatively can be called one per ENV key-value pair to stub:
    #
    #     stub_env('A', 'B')
    #     stub_env('C', 'D')
    #     stub_env('E', 'F')
    def stub_env(key_or_hash, value = nil)
      init_stub unless env_stubbed?
      if key_or_hash.is_a?(Hash)
        key_or_hash.each { |k, v| add_stubbed_value(k, v) }
      else
        add_stubbed_value(key_or_hash, value)
      end
    end

    private

    STUBBED_KEY = "__STUBBED__"

    def add_stubbed_value(key, value)
      key = key.to_s # Support symbols by forcing to string
      allow_brackets(key, value)
      allow_fetch(key, value)
      allow_values_at
      allow_key?(key, value)
    end

    def allow_brackets(key, value)
      allow(ENV).to(receive(:[]).with(key).and_return(value))
    end

    def allow_fetch(key, value)
      allow(ENV).to(receive(:fetch).with(key).and_return(value))
      allow(ENV).to(receive(:fetch).with(key, anything)) do |_, default_val|
        value || default_val
      end
    end

    # Rides on the fetch stub!
    def allow_values_at
      allow(ENV).to(receive(:values_at)) do |*args|
        args.map { |arg| ENV.fetch(arg, nil) }
      end
    end

    def allow_key?(key, value)
      allow(ENV).to(receive(:key?).with(key).and_return(value))
    end

    def env_stubbed?
      ENV.fetch(STUBBED_KEY, nil)
    end

    def init_stub
      allow(ENV).to(receive(:[]).and_call_original)
      allow(ENV).to(receive(:fetch).and_call_original)
      allow(ENV).to(receive(:values_at).and_call_original)
      allow(ENV).to(receive(:key?).and_call_original)
      add_stubbed_value(STUBBED_KEY, true)
    end
  end
end

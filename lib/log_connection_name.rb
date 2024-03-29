# frozen_string_literal: true
require "active_support"
require "log_connection_name/version"

module LogConnectionName
  class Error < StandardError; end
  module AbstractAdapter
    module ConnectionName
      def self.included(model)
        super
        model.prepend MonkeyPatch
      end

      def connection_name=(name)
        @connection_name = name.to_s
      end

      def connection_name
        @connection_name || @config[:connection_name]
      end

      # We use this proxy to push connection name down to instrumenters w/o monkey-patching the log method itself
      class InstrumenterDecorator
        def initialize(adapter, instrumenter)
          @adapter = adapter
          @instrumenter = instrumenter
        end

        def instrument(name, payload = {}, &block)
          payload[:connection_name] ||= @adapter.connection_name
          @instrumenter.instrument(name, payload, &block)
        end

        def method_missing(meth, *args, &block)
          @instrumenter.send(meth, *args, &block)
        end
      end

      module MonkeyPatch
        def initialize(*args)
          super
          @instrumenter = InstrumenterDecorator.new(self, @instrumenter)
        end
      end
    end
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::ConnectionAdapters::AbstractAdapter.include(LogConnectionName::AbstractAdapter::ConnectionName)
end
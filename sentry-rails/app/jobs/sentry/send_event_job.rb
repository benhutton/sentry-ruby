if defined?(ActiveJob)
  module Sentry
    parent_job =
      if defined?(::ApplicationJob) && ::ApplicationJob.ancestors.include?(::ActiveJob::Base)
        ::ApplicationJob
      else
        ::ActiveJob::Base
      end

    class SendEventJob < parent_job
      # the event argument is usually large and creates noise
      self.log_arguments = false if respond_to?(:log_arguments=)

      # this will prevent infinite loop when there's an issue deserializing SentryJob
      if respond_to?(:discard_on)
        discard_on ActiveJob::DeserializationError
      else
        # mimic what discard_on does for Rails 5.0
        rescue_from ActiveJob::DeserializationError do
          logger.error "Discarded #{self.class} due to a #{exception}. The original exception was #{error.cause.inspect}."
        end
      end

      def perform(event, hint = {})
        # users don't need the tracing result of this job
        if transaction = Sentry.get_current_scope.span
          transaction.instance_variable_set(:@sampled, false)
        end

        Sentry.send_event(event, hint)
      end
    end
  end
else
  module Sentry
    class SendEventJob; end
  end
end


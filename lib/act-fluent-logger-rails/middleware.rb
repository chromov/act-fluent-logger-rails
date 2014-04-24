module ActFluentLoggerRails
  class Middleware

    def initialize(app)
      @app = app
    end

    def call(env)
      log = Rails.logger
      if log.respond_to?(:set_global_data)
        log.set_global_data({request_uuid: SecureRandom.uuid})
      end
      @app.call(env)
    end

  end
end

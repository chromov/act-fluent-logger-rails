module ActFluentLoggerRails
  class Middleware

    def initialize(app)
      @app = app
    end

    def call(env)
      log = Rails.logger
      if log.respond_to?(:set_global_data)
        request_uuid = env['request_uuid'] = SecureRandom.uuid
        log.set_global_data({request_uuid: request_uuid})
      end
      @app.call(env)
    end

  end
end

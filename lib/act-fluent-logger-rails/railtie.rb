module ActFluentLoggerRails
  class Railtie < Rails::Railtie
    initializer "act_fluent_logger_rails.insert_middleware" do |app|
      app.config.middleware.insert_before Rails::Rack::Logger, ActFluentLoggerRails::Middleware
    end
  end
end

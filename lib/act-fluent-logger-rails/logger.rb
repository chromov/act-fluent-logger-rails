# -*- coding: utf-8 -*-
require 'fluent-logger'

module ActFluentLoggerRails

  module Logger

    # Severity label for logging. (max 5 char)
    SEV_LABEL = %w(DEBUG INFO WARN ERROR FATAL ANY)

    def self.new(config_file: Rails.root.join("config", "fluent-logger.yml"), log_tags: {})
      Rails.application.config.log_tags = [ ->(request) { request } ] unless log_tags.empty?
      fluent_config = YAML.load(ERB.new(config_file.read).result)[Rails.env]
      settings = {
        tag:  fluent_config['tag'],
        host: fluent_config['fluent_host'],
        port: fluent_config['fluent_port'],
        messages_type: fluent_config['messages_type'],
      }
      level = SEV_LABEL.index(Rails.application.config.log_level.to_s.upcase)
      logger = ActFluentLoggerRails::FluentLogger.new(settings, level, log_tags)
      logger = ActiveSupport::TaggedLogging.new(logger)
      logger.extend self
    end

    def tagged(*tags)
      @request = tags[0][0]
      yield self
    ensure
      flush
    end

    def push_tags(*args)
      tags = args if args.count > 1
      tags = [args[0]].flatten if args.count == 1
      tags ||= []
      @tag = tags.select(&:present?).join('.')
      self
    end

  end

  class FluentLogger < ActiveSupport::Logger
    def initialize(options, level, log_tags)
      self.level = level
      port    = options[:port]
      host    = options[:host]
      @messages_type = (options[:messages_type] || :array).to_sym
      @tag = ''
      @fluent_logger = ::Fluent::Logger::FluentLogger.new(options[:tag], host: host, port: port)
      @severity = 0
      @messages = []
      @log_tags = log_tags
      @map = {}
    end

    def add(severity, message = nil, progname = nil, &block)
      return true if severity < level
      message = (block_given? ? block.call : progname) if message.blank?
      return true if message.blank?
      if message.is_a? Hash
        direct_post(severity, message)
      else
        add_message(severity, message)
      end
      true
    end

    def direct_post(severity, data)
      return if !data.is_a?(Hash) || data.empty?
      @severity = severity if @severity < severity
      data = {level: format_severity(@severity)}.merge(data)
      @fluent_logger.post(@tag, data)
      @severity = 0
    end

    def add_message(severity, message)
      @severity = severity if @severity < severity
      @messages << message
    end

    def [](key)
      @map[key]
    end

    def []=(key, value)
      @map[key] = value
    end

    def flush
      return if @messages.empty?
      messages = if @messages_type == :string
                   @messages.join("\n")
                 else
                   @messages
                 end
      @map[:messages] = messages
      @map[:level] = format_severity(@severity)
      @log_tags.each do |k, v|
        @map[k] = case v
                  when Proc
                    v.call(@request)
                  when Symbol
                    @request.send(v)
                  else
                    v
                  end rescue :error
      end
      @fluent_logger.post(@tag, @map)
      @severity = 0
      @messages.clear
      @map.clear
    end

    def close
      @fluent_logger.close
    end

    def level
      @level
    end

    def level=(l)
      @level = l
    end

    def format_severity(severity)
      ActFluentLoggerRails::Logger::SEV_LABEL[severity] || 'ANY'
    end
  end
end

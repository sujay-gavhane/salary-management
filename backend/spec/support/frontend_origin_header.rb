# Browsers send Origin on every POST/PATCH/PUT/DELETE; request specs mimic that by default.
module FrontendOriginHeader
  %i[post patch put delete].each do |verb|
    define_method(verb) do |path, **options|
      options[:headers] = { "Origin" => Rails.configuration.x.frontend_origin }.merge(options[:headers] || {})
      super(path, **options)
    end
  end
end

RSpec.configure do |config|
  config.include FrontendOriginHeader, type: :request
end

# config/initializers/cors.rb
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins ENV.fetch('SPA_ORIGIN', 'http://localhost:5173')
    resource '/api/*',
      headers: :any,
      methods: [:get, :post, :patch, :put, :delete, :options],
      credentials: true,
      expose: ['X-Total-Count', 'X-Request-Id']
  end
end

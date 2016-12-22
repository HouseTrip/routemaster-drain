module Routemaster
  module Middleware
    class Metrics
      INTERACTION_KEY = 'api_client'.freeze

      attr_reader :client, :source_peer

      def initialize(app, client: nil, source_peer: nil)
        @app    = app
        @client = client
        @source_peer = source_peer
      end

      def call(request_env)
        return @app.call(request_env) unless can_log?(request_env)

        increment_req_count(request_tags(request_env))

        record_latency(request_tags(request_env)) do
          @app.call(request_env).on_complete do |response_env|
            increment_response_count(response_tags(response_env))
          end
        end
      end

      def increment_req_count(tags)
        client.increment("#{INTERACTION_KEY}.request.count", tags: tags)
      end

      def increment_response_count(tags)
        client.increment("#{INTERACTION_KEY}.response.count", tags: tags)
      end

      def record_latency(tags, &block)
        client.time("#{INTERACTION_KEY}.latency", tags: tags) do
          yield
        end
      end

      private

      def can_log?(env)
        client && source_peer
      end

      def destination_peer(env)
        env.url.host
      end

      def peers_tags(env)
        [
          "source:#{source_peer}",
          "destination:#{destination_peer(env)}"
        ]
      end

      def request_tags(env)
        peers_tags(env).concat(["verb:#{env.method}"])
      end

      def response_tags(env)
        peers_tags(env).concat(["status:#{env.status}"])
      end
    end
  end
end

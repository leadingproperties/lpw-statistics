module Lpw
  module Statistics
    class SearchQuery
      include HTTParty
      base_uri ENV['LPW_STATISTIC_APP_URL']

      def initialize
        @options = {
            headers: {
                "Authorization" => "Token token=#{ENV['LPW_STATISTIC_APP_TOKEN']}"
            }
        }
      end

      # {
      #   request_user_agent: +user agent of requester+,
      #   requester_ip: +ip address of requester+,
      #   from_agency_id: attributes[:agency_id],
      #   locale: attributes[:locale],
      #   location_shape: attributes[:location_shape],
      #   location_point: attributes[:location_point],
      #   query_text: attributes[:query_text],
      #   locale: attributes[:locale],
      # }
      def create attributes={}
        self.class.post('/search_queries', @options.merge(
            body: {
                search_query: {
                    request_user_agent: attributes[:request_user_agent],
                    requester_ip: attributes[:requester_ip],
                    from_agency_id: attributes[:agency_id],
                    locale: attributes[:locale],
                    location_shape: attributes[:location_shape],
                    location_point: attributes[:location_point],
                    query_text: attributes[:query_text],
                }
            }
        ))
      end

    end
  end
end
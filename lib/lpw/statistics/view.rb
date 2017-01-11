module Lpw
  module Statistics
    class View
      include HTTParty


      def initialize url, token
        @base_uri = url
        @options = {
            headers: {
                "Authorization" => "Token token=#{token}"
            }
        }
      end

      # {
      #   request_user_agent: +user agent of requester+,
      #   requester_ip: +ip address of requester+,
      #   from_agency_id: attributes[:agency_id],
      #   from_user_id: attributes[:from_user_id],
      #   locale: attributes[:locale],
      #   code: attributes[:code],
      #   "property_object_id": 1111,
      #   "property_agency_id": 32,
      #   "from_agency_name": "test agency",
      #   "action": "view",
      # }

      def create attributes={}
        self.class.post("#{@base_uri}/views", @options.merge(
            body: {
                view: {
                    id: attributes[:id],
                    requester_user_agent: attributes[:user_agent],
                    requester_ip: attributes[:ip],
                    from_agency_id: attributes[:agency_id],
                    from_user_id: attributes[:user_id],
                    locale: attributes[:locale],
                    code: attributes[:code],
                    property_object_id: attributes[:property_object_id],
                    property_agency_id: attributes[:property_agency_id],
                    from_agency_name: attributes[:agency_name],
                    action: attributes[:action],
                    type: attributes[:type]
                }
            }
        ))
      end

    end
  end
end
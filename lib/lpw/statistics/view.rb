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
                    type: attributes[:type],
                    for_sale: attributes[:for_sale],
                    for_rent: attributes[:for_rent]
                }
            }
        ))
      end

      def call_for_statistic options={}
        action = options.fetch(:action, 'show')
        size = options.fetch(:size, 10)
        field = options.fetch(:field, 'property_object_id')
        order = options.fetch(:order, 'desc')
        agency_id = options.fetch(:agency_id)
        user_id = options.fetch(:user_id)
        property_agency_id = options.fetch(:property_agency_id)
        aggr_type = options.fetch(:type, 'objects')
        time_unit = options.fetch(:time_unit, nil)

        @search_definition = {
            "size": 0,
            "query": {
                "constant_score": {
                    "filter": {
                        "bool": {
                            "must": [
                                {"term": {"action": action}},
                            ]
                        }
                    }
                }
            },
            "aggs": {
                "top_results": {
                    "terms": {
                        "field": field,
                        "size": size
                    },
                    "aggs": {
                        "result": {
                            "top_hits": {
                                "sort": [
                                    {
                                        "created_at": {
                                            "order": order
                                        }
                                    }
                                ],
                                "_source": {
                                    "includes": [
                                        "property_object_id",
                                        "code",
                                        "type"
                                    ]
                                },
                                "size": 1
                            }
                        }
                    }
                }
            }
        }

        # Adding type of hits
        case aggr_type
          when /website/
            @search_definition[:query][:constant_score][:filter][:bool][:must] << {"term": {"user_id": user_id}}
          when /objects/
            @search_definition[:query][:constant_score][:filter][:bool][:must] << {"term": {"property_agency_id": property_agency_id}}
        end

        @search_definition[:query][:constant_score][:filter][:bool][:must] << {
            "range": {
                "created_at": {
                    "gte": "now-1#{time_unit}/d",
                    "lt": "now"
                }
            }
        } if time_unit


        self.class.post("#{@base_uri}/views/aggregations", @options.merge(body: {view: @search_definition.to_hash}))

      end

    end
  end
end
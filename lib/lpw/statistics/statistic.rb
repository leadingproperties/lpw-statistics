module Lpw
  module Statistics
    class Statistic

      include Elasticsearch::Persistence::Model

      index_name 'lpw-statistics'

      attribute :code, String
      attribute :agency_id, Integer
      attribute :user_id, Integer
      attribute :property_object_id, Integer
      attribute :property_agency_id, Integer
      attribute :agency_name, String
      attribute :action, String
      attribute :locale, String
      attribute :type, String
      attribute :user_agent, String
      attribute :ip, String

      def self.get_range (from, to)

      end

      # Aggregation to find top records
      # By default showing top 10 show hits for property object
      #
      # @param [Object] options
      # +user_id+ To show all object on user website
      # !Required!
      #
      # +property_agency_id+ To show all hits for agency objects
      #
      #
      # +action+ - action to calculate
      # Values:
      #  - show (showing an object)
      #  - pdf (download PDF from object)
      #  - request (sending from request from object)
      #  *default: show
      #  +size+ - count of records (if we talking about TOP)
      #  Integer.
      #  *default 10
      #  +type+ - Type of aggregation.
      #  Values:
      #  - website
      #  - objects
      #  *default: website
      #  +field+ - main field of aggregation.
      #  *default 'property_object_id'
      #  +order+
      #  Values:
      #  - 'asc'
      #  - 'desc'
      #  *default: 'desc' (more hits on top)
      # +time_unit+
      # Values:
      # all list here: https://www.elastic.co/guide/en/elasticsearch/reference/current/common-options.html#time-units
      # M - Month
      # w - Week
      # d - Day
      # *default none - showing for all time.
      #
      # Examples:
      # Мой сайт - -> в запросе указать  source_type: 'wordpress'
      # Мои объекты ->  все тоже самое только source-type не передаем.
      # Request payload:
      # {
      #   action: 'show', *values: 'show, pdf, request'
      #   time_unit: 'd',  *Values: d/w/M
      #   type: 'wordpress', * нужен в случае "My site"
      #   size: 20
      # }
      #
      # Answer example:
      # answer = {
      #   total: 100,
      #   aggregations: [
      #     {...},
      #     {...}
      #   ]
      # }
      #  Where:
      # 1) Посещаемость общая по всем объектам на сайте за день/неделю/месяц
      # 3) Активность
      #
      # answer['total']
      #
      # 2) Самые популярные объекты у меня на сайте (штук 20)
      # 3.1) Лог последний запросов/скачиваний (например, 20 событий)
      #
      # answer['aggregations']
      #
      # @return [Hash]
      # Will return Hash with aggregation part, and total count part.
      # {
      #   total: _integer_,
      #   aggregations: _array_
      # }
      def self.call_for_statistic options={}
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
        result = self.search(@search_definition)
        {
            total: result.total,
            aggregations: result.response.aggregations['top_results']['buckets']
        }
      end


      private

      # todo: create scroll function to delete old records after backup
      def delete_period (from, to)

      end

    end
  end
end
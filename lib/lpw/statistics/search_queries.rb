module Lpw
  module Statistics
    class SearchQueries
      include Elasticsearch::Persistence::Model

      index_name 'lpw-statistics-sq'

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
      attribute :ip, String, mapping: { type: 'ip' }


    end
  end
end
require "lpw/statistics/version"
require "elasticsearch/persistence/model"
module Lpw
  module Statistics
    class Statistic

      include Elasticsearch::Persistence::Model

      index_name 'lpw-statistics'

      attribute :code, String
      attribute :agency_id, Integer
      attribute :property_object_id, Integer
      attribute :agency_name, String
      attribute :action, String
      attribute :locale, String
      attribute :type, String

      def get_range (from, to)

      end

      def backup

      end

      private

      def clear_old

      end

    end
  end
end

require 'lpw/statistics/version'

require 'pathname'
require 'fileutils'
require 'multi_json'
require 'elasticsearch'
require 'elasticsearch/persistence/model'
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
      attribute :user_agent, String

      def self.get_range (from, to)

      end

      def backup

      end

      private

      def clear_old

      end

    end

    class Backup

      attr_accessor :url,
                    :indices,
                    :size,
                    :scroll

      attr_accessor :mode

      def initialize(&block)

        @url     ||= 'http://localhost:9200'
        @indices ||= '_all'
        @size    ||= 100
        @scroll  ||= '10m'
        @mode    ||= 'single'

        instance_eval(&block) if block_given?
      end

      def client
        @client ||= ::Elasticsearch::Client.new url: url

        # if Rails.env.development?
        #   logger = ActiveSupport::Logger.new(STDERR)
        #   logger.level = Logger::INFO
        #   logger.formatter = proc { |s, d, p, m| "\e[2m#{m}\n\e[0m" }
        #   Elasticsearch::Persistence.client.transport.logger = logger
        # end

      end

      def path
        Rails.root.join('tmp', 'backup')
      end

      def __perform_single
        r = client.search index: indices, search_type: 'scan', scroll: scroll, size: size
        raise Error, "No scroll_id returned in response:\n#{r.inspect}" unless r['_scroll_id']

        while r = client.scroll(scroll_id: r['_scroll_id'], scroll: scroll) and not r['hits']['hits'].empty? do
          r['hits']['hits'].each do |hit|
            FileUtils.mkdir_p "#{path.join hit['_index'], hit['_type']}"
            File.open("#{path.join hit['_index'], hit['_type'], hit['_id']}.json", 'w') do |file|
              file.write MultiJson.dump(hit)
            end
          end
        end
      end

    end
  end
end

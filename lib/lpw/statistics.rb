require 'lpw/statistics/version'

require 'pathname'
require 'fileutils'
require 'multi_json'
require 'elasticsearch'
require 'elasticsearch/persistence/model'
require 'rubygems'
require 'zip'

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
                                    "include": [
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
        }  if time_unit
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

    class Backup

      attr_accessor :host,
                    :port,
                    :user,
                    :password,
                    :scheme,
                    :indices,
                    :size,
                    :scroll,
                    :zip_path,
                    :zip_name


      def initialize(&block)

        @host ||= 'localhost'
        @port ||= '9200'
        @user ||= 'elastic'
        @password ||= 'changeme'
        @scheme ||= 'http'
        @indices ||= '_all'
        @size ||= 100
        @scroll ||= '10m'
        @mode ||= 'single'

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

      def perform!
        r = client.search index: indices, search_type: 'scan', scroll: scroll, size: size
        raise Error, "No scroll_id returned in response:\n#{r.inspect}" unless r['_scroll_id']

        while r = client.scroll(scroll_id: r['_scroll_id'], scroll: scroll) and not r['hits']['hits'].empty? do
          r['hits']['hits'].each do |hit|
            filename = "#{hit['_id']}-#{hit['_source']['created_at']}"
            FileUtils.mkdir_p "#{path.join hit['_index'], hit['_type']}"
            File.open("#{path.join hit['_index'], hit['_type'], filename}.json", 'w') do |file|
              file.write MultiJson.dump(hit)
            end
          end
        end

        # Zip
        self.zip_name = "#{Time.now.to_formatted_s(:number)}-backup.zip"
        self.zip_path ||= path.join(self.zip_name)
        zf = Lpw::Statistics::ZipFileGenerator.new(path, self.zip_path)
        zf.write()
      end

    end

# This is a simple example which uses rubyzip to
# recursively generate a zip file from the contents of
# a specified directory. The directory itself is not
# included in the archive, rather just its contents.
#
# Usage:
# require /path/to/the/ZipFileGenerator/Class
# directoryToZip = "/tmp/input"
# outputFile = "/tmp/out.zip"
# zf = ZipFileGenerator.new(directoryToZip, outputFile)
# zf.write()

    class ZipFileGenerator
      # Initialize with the directory to zip and the location of the output archive.
      def initialize(input_dir, output_file)
        @input_dir = input_dir
        @output_file = output_file
      end

      # Zip the input directory.
      def write
        entries = Dir.entries(@input_dir) - %w(. ..)

        ::Zip::File.open(@output_file, ::Zip::File::CREATE) do |io|
          write_entries entries, '', io
        end
      end

      private

      # A helper method to make the recursion work.
      def write_entries(entries, path, io)
        entries.each do |e|
          zip_file_path = path == '' ? e : File.join(path, e)
          disk_file_path = File.join(@input_dir, zip_file_path)
          puts "Deflating #{disk_file_path}"

          if File.directory? disk_file_path
            recursively_deflate_directory(disk_file_path, io, zip_file_path)
          else
            put_into_archive(disk_file_path, io, zip_file_path)
          end
        end
      end

      def recursively_deflate_directory(disk_file_path, io, zip_file_path)
        io.mkdir zip_file_path
        subdir = Dir.entries(disk_file_path) - %w(. ..)
        write_entries subdir, zip_file_path, io
      end

      def put_into_archive(disk_file_path, io, zip_file_path)
        io.get_output_stream(zip_file_path) do |f|
          f.puts(File.open(disk_file_path, 'rb').read)
        end
      end
    end
  end
end

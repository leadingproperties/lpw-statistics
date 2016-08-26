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

      settings number_of_shards: 1 do
        mapping do
          indexes :ip, type: 'ip'
        end
      end

      attribute :code, String
      attribute :agency_id, Integer
      attribute :property_object_id, Integer
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
      def self.top_records options={}
        action = options.fetch(:action, 'show')
        size = options.fetch(:size, 10)
        field = options.fetch(:field, 'property_object_id')
        order = options.fetch(:order, 'desc')

        @search_definition = {
            "size": 0,
            "query": {
                "match": {
                    "action": action
                }
            },
            "aggs": {
                "top-property_object_id": {
                    "terms": {
                        "field": field,
                        "size": size
                    },
                    "aggs": {
                        "top_property_object_id_hits": {
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
        self.search(@search_definition).response.aggregations
      end


      private

      def delete_period (from, to)

      end

    end

    class Backup

      attr_accessor :url,
                    :indices,
                    :size,
                    :scroll,
                    :zip_path,
                    :zip_name


      def initialize(&block)

        @url ||= 'http://localhost:9200'
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

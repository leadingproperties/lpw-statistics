module Lpw
  module Statistics
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
        @client ||= ::Elasticsearch::Client.new hosts: [
            host: @host,
            port: @port,
            user: @user,
            password: @password,
            scheme: @scheme
        ]

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

  end
end
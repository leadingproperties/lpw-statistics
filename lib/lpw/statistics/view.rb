module Lpw
  module Statistics
    class View
      include HTTParty
      base_uri ENV['LPW_STATISTIC_APP_URL']

      def initialize(description_id, admin_id)
        @description_id = description_id
        @options = {
            headers: {
                "Authorization" => "Token token=#{ENV['LPW_STATISTIC_APP_TOKEN']}"
            },
            body: {
                property_object_description: {admin_id: admin_id}
            }
        }
      end

      def generate_description_by_constructor
        self.class.patch("/property_object_descriptions/#{@description_id}/generate_description_by_constructor", @options)
      end

      def generate_partly_description_by_constructor(locale, part)
        @options[:body][:property_object_description][:locale] = locale
        @options[:body][:property_object_description][:partly] = part
        self.class.patch("/property_object_descriptions/#{@description_id}/generate_partly_description_by_constructor", @options)
      end

    end
  end
end
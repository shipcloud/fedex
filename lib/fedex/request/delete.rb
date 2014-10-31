require 'fedex/request/base'

module Fedex
  module Request
    class Delete < Base

      attr_reader :tracking_number

      def initialize(credentials, options={})
        requires!(options, :tracking_number)

        @tracking_number  = options[:tracking_number]
        @deletion_control = options[:deletion_control] || 'DELETE_ALL_PACKAGES'
        @credentials  = credentials
      end

      def process_request
        api_response = self.class.post(api_url, :body => build_xml)
        puts api_response if @debug == true
        response = parse_response(api_response)
        unless success?(response)
          error_code = error_message = ''
          if response[:shipment_reply]
            first_notification = [response[:shipment_reply][:notifications]].flatten.first
            error_message = first_notification[:message]
            error_code = first_notification[:code]
          else
            error_code = api_response["Fault"]["detail"]["fault"]["errorCode"]
            error_message = "#{api_response["Fault"]["detail"]["fault"]["reason"]} #{api_response["Fault"]["detail"]["fault"]["details"]["ValidationFailureDetail"]["message"].join(', ')}"
          end rescue $1
          raise RateError.new(error_message, error_code, api_response)
        end
      end

      private

      # Build xml Fedex Web Service request
      def build_xml
        builder = Nokogiri::XML::Builder.new do |xml|
          xml.DeleteShipmentRequest(:xmlns => "http://fedex.com/ws/ship/v#{service[:version]}"){
            add_web_authentication_detail(xml)
            add_client_detail(xml)
            add_version(xml)
            xml.TrackingId {
              xml.TrackingIdType 'FEDEX'
              xml.TrackingNumber @tracking_number
            }
            xml.DeletionControl @deletion_control
          }
        end
        builder.doc.root.to_xml
      end

      def service
        { :id => 'ship', :version => Fedex::API_VERSION }
      end

      # Successful request
      def success?(response)
        response[:shipment_reply] &&
          %w{SUCCESS WARNING NOTE}.include?(response[:shipment_reply][:highest_severity])
      end
    end
  end
end

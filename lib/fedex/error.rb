
module Fedex
  class Error < StandardError
    attr_accessor :response, :code

    def self.from_response(response)
      p "response:  #{response}"
      message, code = parse_error(response)
      new(message, code, response)
    end

    def inspect
      if code.present?
        "#{code}: #{message}"
      else
        message
      end
    end

    def self.parse_error(response)
      if fault = response['Fault']
        parse_soap_fault(fault)
      else
        notifications = response.flatten[1].fetch('Notifications', {})
        [notifications.fetch('Message', ''), notifications.fetch('Code', '')]
      end
    end

    def self.parse_soap_fault(fault)
      fault_detail = fault.fetch('detail', {}).fetch('fault', {})
      code = fault_detail['errorCode']

      validation_failure_details = fault_detail['details']['ValidationFailureDetail']
      messages = []
      validation_failure_details['message'].each_with_index do |message, index|
        messages << "#{validation_failure_details['xmlLocation'][index].keys.first}: #{message}"
      end

      message = "#{fault_detail['reason']} #{messages.join(', ')}"
      [message, code]
    end

    def initialize(message = '', code = nil, response =  nil)
      super(message)
      @code = code
      @response = response
    end

    # RateError = Class.new(self)

  end
  class RateError < Error; end
end

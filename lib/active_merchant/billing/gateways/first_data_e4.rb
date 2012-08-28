module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class FirstDataE4Gateway < Gateway
      self.test_url = 'https://api.demo.globalgatewaye4.firstdata.com/transaction/v11'
      self.live_url = 'https://api.globalgatewaye4.firstdata.com/transaction/v11'

      E4_API_VERSION = '11'

      # The countries the gateway supports merchants from as 2 digit ISO country codes
      self.supported_countries = %w(US)

      # The card types supported by the payment gateway
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      # The homepage URL of the gateway
      self.homepage_url = 'https://globalgatewaye4.firstdata.com'

      # The name of the gateway
      self.display_name = 'First Data Global Gateway E4'

      TRANSACTIONS = {
          :purchase => "00",
          :authorize => "01",
          :capture => "02",
          :forced_post => "03",
          :refund => "04",
          :authorize_only => "05",
          :paypal_order => "07",
          :void => "13",
          :tagged_capture => "32",
          :tagged_void => "33",
          :tagged_refund => "34",
          :cashout => "83",
          :activation => "85",
          :balance_inquiry => "86",
          :reload => "88",
          :deactivation => "89"
      }

      def initialize(options = {})
        requires!(options, :login, :password)
        @options = options
        super
      end

      # Completes an existing pre-authorization by referencing an authorization
      # number. If required, an additional 15% of the dollar value of the
      # authorization can be levied with this transaction.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be authorized as an Integer value in cents.
      # * <tt>creditcard</tt> -- The CreditCard details for the transaction.
      # * <tt>options</tt> -- A hash of optional parameters.
      def authorize(money, creditcard, options = {})
        post = {}
        add_amount(post, money)
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)

        commit(:authorize, post)
      end

      # Sends through sale and request for funds to be charged to cardholder’s
      # credit card.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be purchased as an Integer value in cents.
      # * <tt>creditcard</tt> -- The CreditCard details for the transaction.
      # * <tt>options</tt> -- A hash of optional parameters.
      def purchase(money, creditcard, options = {})
        post = {}
        add_amount(post, money)
        add_invoice(post, options)
        add_creditcard(post, creditcard)
        add_address(post, creditcard, options)

        commit(:purchase, post)
      end

      # Completes an existing pre-authorization by referencing an authorization
      # number. If required, an additional 15% of the dollar value of the
      # authorization can be levied with this transaction.
      #
      # ==== Parameters
      #
      # * <tt>money</tt> -- The amount to be captured as an Integer value in cents.
      # * <tt>authorization</tt> -- The authorization returned from the previous authorize request
      # * <tt>options</tt> -- An optional hash of parameters.
      def capture(money, authorization, options = {})
        reference, amount, tag = split_authorization(authorization)

        post = {}
        add_amount(post, money)
        add_authorization(post, reference)
        add_transaction_tag(post, tag)
        commit(:tagged_capture, post)
      end

      def refund(money, authorization, options={})
        reference, amount, tag = split_authorization(authorization)

        post = {}
        add_amount(post, money)
        add_authorization(post, reference)
        add_transaction_tag(post, tag)

        commit(:tagged_refund, post)
      end

      def void(authorization, options = {})
        reference, amount, tag = split_authorization(authorization)

        post = {}
        add_amount(post, amount.to_i)
        add_authorization(post, reference)
        add_transaction_tag(post, tag)

        commit(:tagged_void, post)
      end

      private

      def add_amount(post, money)
        post[:amount] = amount(money)
      end

      def add_authorization(post, authorization)
        post["authorization_num"] = authorization
      end

      def add_address(post, creditcard, options)
        if billing_address = options[:billing_address] || options[:address]
          street = billing_address[:address1]
          street += " #{billing_address[:address2]}" if billing_address[:address2].present?
          post["cc_verification_str1"] = [
              street.strip(),
              billing_address[:zip].strip(),
              billing_address[:city].strip(),
              billing_address[:state].strip(),
              billing_address[:country].strip()
          ].join("|")
        end

        if shipping_address = options[:shipping_address]
          post["level3_shiptoaddress_type"] = {}
          post["level3_shiptoaddress_type"]["address1"] = shipping_address[:address1]
          post["level3_shiptoaddress_type"]["city"] = shipping_address[:city]
          post["level3_shiptoaddress_type"]["state"] = shipping_address[:state]
          post["level3_shiptoaddress_type"]["zip"] = shipping_address[:zip]
          post["level3_shiptoaddress_type"]["country"] = shipping_address[:country]
          post["level3_shiptoaddress_type"]["phone"] = shipping_address[:phone]
          post["level3_shiptoaddress_type"]["name"] = shipping_address[:name]
          post["level3_shiptoaddress_type"]["email"] = options[:email]
        end
      end

      def add_invoice(post, options)
        post["reference_no"] = options[:order_id]
      end

      def add_creditcard(post, creditcard)
        post["cc_number"] = creditcard.number
        post["cc_expiry"] = expdate(creditcard)
        post["cardholder_name"] = cardholder_name(creditcard)
        post["cc_verification_str1"] = creditcard.verification_value if creditcard.verification_value?
        post["cvd_presence_ind"] = "1" if creditcard.verification_value?
      end

      def add_transaction_tag(post, tag)
        post["transaction_tag"] = tag.to_i
      end

      def parse(body)
        ActiveSupport::JSON.decode(body)
      end

      def commit(action, parameters)
        url = test? ? self.test_url : self.live_url
        data = ssl_post url, post_data(action, parameters), headers

        response = parse(data)
        message = message_from(response)

        ActiveMerchant::Billing::Response.new(
            success?(response),
            message,
            response,
            {
                test:          test?,
                authorization: authorization_from(response),
                cvv_result:    response["cvv2"]
            })
      end

      def success?(response)
        response["transaction_approved"] == 1
      end

      def message_from(response)
        response["bank_message"]
      end

      def post_data(action, parameters = {})
        post = {}

        post["gateway_id"] = @options[:login]
        post["Password"] = @options[:password]
        post["transaction_type"] = TRANSACTIONS[action]

        post.merge(parameters).to_json
      end

      def authorization_from(response)
        "#{response["authorization_num"]};#{response["amount"] * 100};#{response["transaction_tag"]}"
      end

      def split_authorization(string)
        string.split(";")
      end

      def cardholder_name(creditcard)
        "#{creditcard.first_name} #{creditcard.last_name}"
      end

      def expdate(creditcard)
        year = sprintf("%.4i", creditcard.year)
        month = sprintf("%.2i", creditcard.month)

        "#{month}#{year[-2..-1]}"
      end

      def headers
        {
            "Authorization" => basic_auth,
            "Accept"        => "application/json",
            "Content-Type"  => "application/json"
        }
      end

      def basic_auth
        'Basic ' + ["#{@options[:login]}:#{@options[:password]}"].pack('m').delete("\r\n")
      end
    end
  end
end


require 'test_helper'

class FirstDataE4Test < Test::Unit::TestCase
  def setup
    Base.mode = :test

    @gateway = FirstDataE4Gateway.new(
                 :login => 'login',
                 :password => 'password'
               )

    @credit_card = credit_card
    @amount = 100

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_instance_of Response, response
    assert_success response

    # Replace with authorization number from the successful response
    assert_equal "ET1000;#@amount;11111", response.authorization
    assert response.test?
  end

  def test_unsuccessful_request
    @gateway.expects(:ssl_post).returns(failed_purchase_response)

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert response.test?
  end

  def test_successful_authorization
    @gateway.expects(:ssl_post).returns(successful_authorization_response)

    assert response = @gateway.authorize(@amount, @credit_card)
    assert_instance_of Response, response
    assert_success response
    assert_equal "ET12345;#@amount;22222", response.authorization
  end

  def test_failed_authorization
    @gateway.expects(:ssl_post).returns(failed_authorization_response)

    assert response = @gateway.authorize(@amount, @credit_card)
    assert_instance_of Response, response
    assert_failure response
    assert_equal "ET12345;#@amount;33333", response.authorization
  end

  private

  # Place raw successful response from gateway here
  def successful_authorization_response
    "{\"authorization_num\":\"ET12345\",\"transaction_approved\":1,\"transaction_tag\":22222,\"amount\":#@amount}"
  end

  def successful_purchase_response
    "{\"authorization_num\":\"ET1000\",\"transaction_approved\":1,\"transaction_tag\":11111,\"amount\":#@amount}"
  end

  # Place raw failed response from gateway here
  def failed_authorization_response
    "{\"authorization_num\":\"ET12345\",\"transaction_approved\":0,\"transaction_tag\":33333,\"amount\":#@amount}"
  end
  def failed_purchase_response
    '{"transaction_approved":0}'
  end
end

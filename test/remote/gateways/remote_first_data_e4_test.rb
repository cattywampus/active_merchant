require 'test_helper'

class RemoteFirstDataE4Test < Test::Unit::TestCase


  def setup
    Base.mode = :test

    @gateway = FirstDataE4Gateway.new(fixtures(:first_data_e4))

    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @declined_card = credit_card('4005550000000019')
    @declined_card.verification_value='111'

    @options = {
      :order_id => '1',
      :billing_address => address,
      :description => 'Store Purchase'
    }
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'Transaction Normal', response.message
  end

  #def test_unsuccessful_purchase
  #  assert response = @gateway.purchase(@amount, @declined_card, @options)
  #  assert_failure response
  #  assert_equal 'REPLACE WITH FAILED PURCHASE MESSAGE', response.message
  #end

  def test_authorize_and_capture
    amount = @amount
    assert auth = @gateway.authorize(amount, @credit_card, @options)
    assert_success auth
    assert_equal 'Transaction Normal', auth.message
    assert auth.authorization
    assert capture = @gateway.capture(amount, auth.authorization)
    assert_success capture
    assert_equal 'Transaction Normal', capture.message
  end

  def test_failed_capture
    e = assert_raise ActiveMerchant::ResponseError do
      @gateway.capture(@amount, '', {transaction_tag: 0})
    end

    assert_match /Failed with 400 Bad Request/i, e.message
  end

  def test_invalid_login
    gateway = FirstDataE4Gateway.new(
                :login => '',
                :password => ''
              )
    e = assert_raise ActiveMerchant::ResponseError do
      gateway.purchase(@amount, @credit_card, @options)
    end

    assert_match /Failed with 401 Authorization Required/i, e.message
  end

  def test_successful_purchase_and_void
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert void = @gateway.void(purchase.authorization)
    assert_success void
  end

  def test_successful_purchase_and_refund
    amount = 700
    assert purchase = @gateway.purchase(amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(amount, purchase.authorization)
    assert_success refund
  end
end

require 'test_helper'

class RemoteCyberSourceTest < Test::Unit::TestCase
  # Reduce code duplication: use `assert_successful_response` when feasible!
  def setup
    Base.mode = :test

    @gateway = CyberSourceGateway.new({ nexus: 'NC' }.merge(fixtures(:cyber_source)))
    @gateway_latam = CyberSourceGateway.new({}.merge(fixtures(:cyber_source_latam_pe)))

    @credit_card = credit_card('4111111111111111', verification_value: '987')
    @declined_card = credit_card('801111111111111')
    @master_credit_card = credit_card('5555555555554444',
      verification_value: '321',
      month: '12',
      year: (Time.now.year + 2).to_s,
      brand: :master)
    @pinless_debit_card = credit_card('4002269999999999')
    @elo_credit_card = credit_card('5067310000000010',
      verification_value: '321',
      month: '12',
      year: (Time.now.year + 2).to_s,
      brand: :elo)
    @three_ds_unenrolled_card = credit_card('4000000000000051',
      verification_value: '321',
      month: '12',
      year: (Time.now.year + 2).to_s,
      brand: :visa)
    @three_ds_enrolled_card = credit_card('4000000000000002',
      verification_value: '321',
      month: '12',
      year: (Time.now.year + 2).to_s,
      brand: :visa)
    @three_ds_invalid_card = credit_card('4000000000000010',
      verification_value: '321',
      month: '12',
      year: (Time.now.year + 2).to_s,
      brand: :visa)
    @three_ds_enrolled_mastercard = credit_card('5200000000001005',
      verification_value: '321',
      month: '12',
      year: (Time.now.year + 2).to_s,
      brand: :master)

    @amount = 100

    @options = {
      order_id: generate_unique_id,
      line_items: [
        {
          declared_value: 100,
          quantity: 2,
          code: 'default',
          description: 'Giant Walrus',
          sku: 'WA323232323232323',
          tax_amount: 10,
          national_tax: 5
        }
      ],
      currency: 'USD',
      ignore_avs: 'true',
      ignore_cvv: 'true',
      commerce_indicator: 'internet',
      user_po: 'ABC123',
      taxable: true
    }

    @subscription_options = {
      order_id: generate_unique_id,
      credit_card: @credit_card,
      subscription: {
        frequency: 'weekly',
        start_date: Date.today.next_week,
        occurrences: 4,
        auto_renew: true,
        amount: 100
      }
    }

    @issuer_additional_data = 'PR25000000000011111111111112222222sk111111111111111111111111111'
    + '1111111115555555222233101abcdefghijkl7777777777777777777777777promotionCde'
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end

  def test_network_tokenization_transcript_scrubbing
    credit_card = network_tokenization_credit_card('4111111111111111',
      brand: 'visa',
      eci: '05',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=')

    transcript = capture_transcript(@gateway) do
      @gateway.authorize(@amount, credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(credit_card.number, transcript)
    assert_scrubbed(credit_card.payment_cryptogram, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end

  def test_successful_authorization
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(response)
    assert !response.authorization.blank?
  end

  def test_successful_authorization_with_reconciliation_id
    options = @options.merge(reconciliation_id: '1936831')
    assert response = @gateway.authorize(@amount, @credit_card, options)
    assert_successful_response(response)
    assert !response.authorization.blank?
  end

  def test_successful_authorize_with_solution_id
    ActiveMerchant::Billing::CyberSourceGateway.application_id = 'A1000000'
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(response)
    assert !response.authorization.blank?
  ensure
    ActiveMerchant::Billing::CyberSourceGateway.application_id = nil
  end

  def test_successful_authorize_with_solution_id_and_stored_creds
    ActiveMerchant::Billing::CyberSourceGateway.application_id = 'A1000000'
    @options[:stored_credential] = {
      initiator: 'cardholder',
      reason_type: '',
      initial_transaction: true,
      network_transaction_id: ''
    }
    @options[:commerce_indicator] = 'internet'

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(response)
    assert !response.authorization.blank?
  ensure
    ActiveMerchant::Billing::CyberSourceGateway.application_id = nil
  end

  def test_successful_authorization_with_issuer_additional_data
    @options[:issuer_additional_data] = @issuer_additional_data

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(response)
    assert !response.authorization.blank?
  end

  def test_successful_authorization_with_issuer_additional_data_and_partner_solution_id
    @options[:issuer_additional_data] = @issuer_additional_data

    ActiveMerchant::Billing::CyberSourceGateway.application_id = 'A1000000'

    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(auth)

    assert void = @gateway.void(auth.authorization, @options)
    assert_successful_response(void)
  ensure
    ActiveMerchant::Billing::CyberSourceGateway.application_id = nil
  end

  def test_successful_authorize_with_merchant_descriptor_and_partner_solution_id
    @options[:merchant_descriptor] = 'Spreedly'

    ActiveMerchant::Billing::CyberSourceGateway.application_id = 'A1000000'

    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(auth)

    assert void = @gateway.void(auth.authorization, @options)
    assert_successful_response(void)
  ensure
    ActiveMerchant::Billing::CyberSourceGateway.application_id = nil
  end

  def test_successful_authorize_with_issuer_additional_data_stored_creds_merchant_desc_and_partner_solution_id
    @options[:issuer_additional_data] = @issuer_additional_data
    @options[:stored_credential] = {
      initiator: 'cardholder',
      reason_type: '',
      initial_transaction: true,
      network_transaction_id: ''
    }
    @options[:commerce_indicator] = 'internet'
    @options[:merchant_descriptor] = 'Spreedly'

    ActiveMerchant::Billing::CyberSourceGateway.application_id = 'A1000000'

    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(auth)
  ensure
    ActiveMerchant::Billing::CyberSourceGateway.application_id = nil
  end

  def test_successful_authorization_with_elo
    assert response = @gateway.authorize(@amount, @elo_credit_card, @options)
    assert_successful_response(response)
    assert !response.authorization.blank?
  end

  def test_successful_authorization_with_installment_data
    options = @options.merge(installment_total_count: 5, installment_plan_type: 1, first_installment_date: '300101')
    assert response = @gateway.authorize(@amount, @credit_card, options)
    assert_successful_response(response)
    assert !response.authorization.blank?
  end

  def test_successful_authorization_with_merchant_tax_id
    options = @options.merge(merchant_tax_id: '123')
    assert response = @gateway.authorize(@amount, @credit_card, options)
    assert_successful_response(response)
  end

  def test_successful_authorization_with_sales_slip_number
    options = @options.merge(sales_slip_number: '456')
    assert response = @gateway.authorize(@amount, @credit_card, options)
    assert_successful_response(response)
  end

  def test_successful_authorization_with_airline_agent_code
    options = @options.merge(airline_agent_code: '7Q')
    assert response = @gateway.authorize(@amount, @credit_card, options)
    assert_successful_response(response)
  end

  def test_unsuccessful_authorization
    assert response = @gateway.authorize(@amount, @declined_card, @options)
    assert response.test?
    assert_equal 'Invalid account number', response.message
    assert_equal false, response.success?
  end

  def test_purchase_and_void
    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_successful_response(purchase)
    assert void = @gateway.void(purchase.authorization, @options)
    assert_successful_response(void)
  end

  # Note: This test will only pass with test account credentials which
  # have asynchronous adjustments enabled.
  def test_successful_asynchronous_adjust
    assert authorize = @gateway_latam.authorize(@amount, @credit_card, @options)
    assert_successful_response(authorize)
    assert adjust = @gateway_latam.adjust(@amount * 2, authorize.authorization, @options)
    assert_success adjust
    assert capture = @gateway_latam.capture(@amount, authorize.authorization, @options.merge({ national_tax_indicator: 1 }))
    assert_successful_response(capture)
  end

  def test_authorize_and_void
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(auth)
    assert void = @gateway.void(auth.authorization, @options)
    assert_successful_response(void)
  end

  def test_capture_and_void
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(auth)
    assert capture = @gateway.capture(@amount, auth.authorization, @options.merge({ national_tax_indicator: 1 }))
    assert_successful_response(capture)
    assert void = @gateway.void(capture.authorization, @options)
    assert_successful_response(void)
  end

  def test_capture_and_void_with_elo
    assert auth = @gateway.authorize(@amount, @elo_credit_card, @options)
    assert_successful_response(auth)
    assert capture = @gateway.capture(@amount, auth.authorization, @options.merge({ national_tax_indicator: 1 }))
    assert_successful_response(capture)
    assert void = @gateway.void(capture.authorization, @options)
    assert_successful_response(void)
  end

  def test_void_with_issuer_additional_data
    @options[:issuer_additional_data] = @issuer_additional_data

    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(auth)
    assert void = @gateway.void(auth.authorization, @options)
    assert_successful_response(void)
  end

  def test_void_with_mdd_fields
    (1..20).each { |e| @options["mdd_field_#{e}".to_sym] = "value #{e}" }

    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(auth)
    assert void = @gateway.void(auth.authorization, @options)
    assert_successful_response(void)
  end

  def test_successful_void_with_solution_id
    ActiveMerchant::Billing::CyberSourceGateway.application_id = 'A1000000'

    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(auth)

    assert void = @gateway.void(auth.authorization, @options)
    assert_successful_response(void)
  ensure
    ActiveMerchant::Billing::CyberSourceGateway.application_id = nil
  end

  def test_successful_tax_calculation
    assert response = @gateway.calculate_tax(@credit_card, @options)
    assert response.params['totalTaxAmount']
    assert_not_equal '0', response.params['totalTaxAmount']
    assert_successful_response(response)
  end

  def test_successful_purchase
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_successful_purchase_with_national_tax_indicator
    assert purchase = @gateway.purchase(@amount, @credit_card, @options.merge(national_tax_indicator: 1))
    assert_successful_response(purchase)
  end

  def test_successful_purchase_with_issuer_additional_data
    @options[:issuer_additional_data] = @issuer_additional_data

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_successful_purchase_with_merchant_descriptor
    @options[:merchant_descriptor] = 'Spreedly'

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_successful_purchase_with_issuer_additional_data_and_partner_solution_id
    @options[:issuer_additional_data] = @issuer_additional_data

    ActiveMerchant::Billing::CyberSourceGateway.application_id = 'A1000000'

    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_successful_response(purchase)
  ensure
    ActiveMerchant::Billing::CyberSourceGateway.application_id = nil
  end

  def test_successful_purchase_with_merchant_descriptor_and_partner_solution_id
    @options[:merchant_descriptor] = 'Spreedly'

    ActiveMerchant::Billing::CyberSourceGateway.application_id = 'A1000000'

    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_successful_response(purchase)
  ensure
    ActiveMerchant::Billing::CyberSourceGateway.application_id = nil
  end

  def test_successful_purchase_with_issuer_additional_data_stored_creds_merchant_desc_and_partner_solution_id
    @options[:issuer_additional_data] = @issuer_additional_data
    @options[:stored_credential] = {
      initiator: 'cardholder',
      reason_type: '',
      initial_transaction: true,
      network_transaction_id: ''
    }
    @options[:commerce_indicator] = 'internet'
    @options[:merchant_descriptor] = 'Spreedly'

    ActiveMerchant::Billing::CyberSourceGateway.application_id = 'A1000000'

    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_successful_response(purchase)
  ensure
    ActiveMerchant::Billing::CyberSourceGateway.application_id = nil
  end

  def test_successful_purchase_with_reconciliation_id
    options = @options.merge(reconciliation_id: '1936831')
    assert response = @gateway.purchase(@amount, @credit_card, options)
    assert_successful_response(response)
  end

  def test_successful_authorize_with_customer_id
    options = @options.merge(customer_id: '7500BB199B4270EFE05348D0AFCAD')
    assert response = @gateway.authorize(@amount, @credit_card, options)
    assert_successful_response(response)
  end

  def test_authorize_with_national_tax_indicator
    assert authorize = @gateway.authorize(@amount, @credit_card, @options.merge(national_tax_indicator: 1))
    assert_successful_response(authorize)
  end

  def test_successful_purchase_with_customer_id
    options = @options.merge(customer_id: '7500BB199B4270EFE00588D0AFCAD')
    assert response = @gateway.purchase(@amount, @credit_card, options)
    assert_successful_response(response)
  end

  def test_successful_purchase_with_elo
    assert response = @gateway.purchase(@amount, @elo_credit_card, @options)
    assert_successful_response(response)
  end

  def test_successful_purchase_sans_options
    assert response = @gateway.purchase(@amount, @credit_card)
    assert_equal 'Successful transaction', response.message
    assert_successful_response(response)
  end

  def test_successful_purchase_with_billing_address_override
    billing_address = {
      address1: '111 North Pole Lane',
      city: 'Santaland',
      state: '',
      phone: nil
    }
    @options[:billing_address] = billing_address
    @options[:email] = 'override@example.com'
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_equal true, response.success?
    assert_successful_response(response)
  end

  def test_successful_purchase_with_long_country_name
    @options[:billing_address] = address(country: 'united states', state: 'NC')
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_successful_purchase_without_decision_manager
    @options[:decision_manager_enabled] = 'false'
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_successful_purchase_with_decision_manager_profile
    @options[:decision_manager_enabled] = 'true'
    @options[:decision_manager_profile] = 'Regular'
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_successful_purchase_with_solution_id
    ActiveMerchant::Billing::CyberSourceGateway.application_id = 'A1000000'
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_successful_response(response)
    assert !response.authorization.blank?
  ensure
    ActiveMerchant::Billing::CyberSourceGateway.application_id = nil
  end

  def test_successful_purchase_with_solution_id_and_stored_creds
    ActiveMerchant::Billing::CyberSourceGateway.application_id = 'A1000000'
    @options[:stored_credential] = {
      initiator: 'cardholder',
      reason_type: '',
      initial_transaction: true,
      network_transaction_id: ''
    }
    @options[:commerce_indicator] = 'internet'

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_successful_response(response)
    assert !response.authorization.blank?
  ensure
    ActiveMerchant::Billing::CyberSourceGateway.application_id = nil
  end

  def test_successful_purchase_with_country_submitted_as_empty_string
    @options[:billing_address] = { country: '' }
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_unsuccessful_purchase
    assert response = @gateway.purchase(@amount, @declined_card, @options)
    assert_equal 'Invalid account number', response.message
    assert_failure response
  end

  def test_authorize_and_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(auth)

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_successful_response(capture)
  end

  def test_authorize_and_capture_with_elo
    assert auth = @gateway.authorize(@amount, @elo_credit_card, @options)
    assert_successful_response(auth)

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_successful_response(capture)
  end

  def test_successful_capture_with_issuer_additional_data
    @options[:issuer_additional_data] = @issuer_additional_data
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(auth)

    assert response = @gateway.capture(@amount, auth.authorization)
    assert_successful_response(response)
    assert !response.authorization.blank?
  end

  def test_successful_capture_with_solution_id
    ActiveMerchant::Billing::CyberSourceGateway.application_id = 'A1000000'
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(auth)

    assert response = @gateway.capture(@amount, auth.authorization, @options.merge({ national_tax_indicator: 1 }))
    assert_successful_response(response)
    assert !response.authorization.blank?
  ensure
    ActiveMerchant::Billing::CyberSourceGateway.application_id = nil
  end

  def test_successful_authorization_and_failed_capture
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(auth)

    assert capture = @gateway.capture(@amount + 100000000, auth.authorization, @options.merge({ national_tax_indicator: 1 }))
    assert_failure capture
    assert_equal 'One or more fields contains invalid data: (Amount limit)', capture.message
  end

  def test_failed_capture_bad_auth_info
    assert @gateway.authorize(@amount, @credit_card, @options)
    assert capture = @gateway.capture(@amount, 'a;b;c', @options.merge({ national_tax_indicator: 1 }))
    assert_failure capture
  end

  def test_invalid_login
    gateway = CyberSourceGateway.new(login: 'asdf', password: 'qwer')
    assert response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal "wsse:FailedCheck: \nSecurity Data : UsernameToken authentication failed.\n", response.message
  end

  # Unable to test refunds for Elo cards, as the test account is setup to have
  # Elo transactions routed to Comercio Latino which has very specific rules on
  # refunds (i.e. that you cannot do a "Stand-Alone" refund). This means we need
  # to go through a Capture cycle at least a day before submitting a refund.
  def test_successful_refund
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_successful_response(response)

    assert response = @gateway.refund(@amount, response.authorization)
    assert_successful_response(response)
  end

  def test_successful_refund_with_solution_id
    ActiveMerchant::Billing::CyberSourceGateway.application_id = 'A1000000'

    assert purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_successful_response(purchase)

    assert refund = @gateway.refund(@amount, purchase.authorization, @options)
    assert_successful_response(refund)
  ensure
    ActiveMerchant::Billing::CyberSourceGateway.application_id = nil
  end

  def test_network_tokenization_authorize_and_capture
    credit_card = network_tokenization_credit_card('4111111111111111',
      brand: 'visa',
      eci: '05',
      payment_cryptogram: 'EHuWW9PiBkWvqE5juRwDzAUFBAk=')

    assert auth = @gateway.authorize(@amount, credit_card, @options)
    assert_successful_response(auth)

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_successful_response(capture)
  end

  def test_successful_authorize_with_mdd_fields
    (1..20).each { |e| @options["mdd_field_#{e}".to_sym] = "value #{e}" }

    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_successful_purchase_with_mdd_fields
    (1..20).each { |e| @options["mdd_field_#{e}".to_sym] = "value #{e}" }
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_successful_capture_with_mdd_fields
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(auth)

    (1..20).each { |e| @options["mdd_field_#{e}".to_sym] = "value #{e}" }
    assert capture = @gateway.capture(@amount, auth.authorization, @options.merge({ national_tax_indicator: 1 }))
    assert_successful_response(capture)
  end

  def test_merchant_description
    merchant_options = {
      merchantInformation: {
        merchantDescriptor: {
          name: 'Test Name',
          address1: '123 Main Dr',
          locality: 'Durham'
        }
      }
    }

    assert response = @gateway.purchase(@amount, @credit_card, @options.merge(merchant_options))
    assert_successful_response(response)
  end

  def test_successful_capture_with_tax
    assert auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(auth)

    capture_options = @options.merge(local_tax_amount: '0.17', national_tax_amount: '0.05', national_tax_indicator: 1)
    assert capture = @gateway.capture(@amount, auth.authorization, capture_options)
    assert_successful_response(capture)
  end

  def test_successful_authorize_with_nonfractional_currency
    assert response = @gateway.authorize(100, @credit_card, @options.merge(currency: 'JPY'))
    assert_equal '1', response.params['amount']
    assert_successful_response(response)
  end

  def test_successful_subscription_authorization
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert_successful_response(response)

    assert response = @gateway.authorize(@amount, response.authorization, order_id: generate_unique_id)
    assert_successful_response(response)
    assert !response.authorization.blank?
  end

  def test_successful_subscription_purchase
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert_successful_response(response)

    assert response = @gateway.purchase(@amount, response.authorization, order_id: generate_unique_id)
    assert_successful_response(response)
  end

  def test_successful_subscription_purchase_with_elo
    assert response = @gateway.store(@elo_credit_card, @subscription_options)
    assert_successful_response(response)

    assert response = @gateway.purchase(@amount, response.authorization, order_id: generate_unique_id)
    assert_successful_response(response)
  end

  def test_successful_standalone_credit_to_card
    assert response = @gateway.credit(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_successful_standalone_credit_to_card_with_merchant_descriptor
    @options[:merchant_descriptor] = 'Spreedly'
    assert response = @gateway.credit(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_successful_standalone_credit_to_card_with_issuer_additional_data
    @options[:issuer_additional_data] = @issuer_additional_data
    assert response = @gateway.credit(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_successful_standalone_credit_to_card_with_mdd_fields
    (1..20).each { |e| @options["mdd_field_#{e}".to_sym] = "value #{e}" }
    assert response = @gateway.credit(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_failed_standalone_credit_to_card
    assert response = @gateway.credit(@amount, @declined_card, @options)

    assert_equal 'Invalid account number', response.message
    assert_failure response
    assert response.test?
  end

  def test_successful_standalone_credit_to_subscription
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert_successful_response(response)

    assert response = @gateway.credit(@amount, response.authorization, order_id: generate_unique_id)
    assert_successful_response(response)
  end

  def test_successful_standalone_credit_to_subscription_with_merchant_descriptor
    @subscription_options[:merchant_descriptor] = 'Spreedly'
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert_successful_response(response)

    assert response = @gateway.credit(@amount, response.authorization, order_id: generate_unique_id)
    assert_successful_response(response)
  end

  def test_successful_create_subscription
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert_successful_response(response)
  end

  def test_successful_create_subscription_with_elo
    assert response = @gateway.store(@elo_credit_card, @subscription_options)
    assert_successful_response(response)
  end

  def test_successful_create_subscription_with_setup_fee
    assert response = @gateway.store(@credit_card, @subscription_options.merge(setup_fee: 100))
    assert_successful_response(response)
  end

  def test_successful_create_subscription_with_monthly_options
    response = @gateway.store(@credit_card, @subscription_options.merge(setup_fee: 99.0, subscription: { amount: 49.0, automatic_renew: false, frequency: 'monthly' }))
    assert_equal 'Successful transaction', response.message
    response = @gateway.retrieve(response.authorization, order_id: @subscription_options[:order_id])
    assert_equal '0.49', response.params['recurringAmount']
    assert_equal 'monthly', response.params['frequency']
  end

  def test_successful_update_subscription_creditcard
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert_successful_response(response)

    assert response = @gateway.update(response.authorization, @credit_card, { order_id: generate_unique_id, setup_fee: 100 })
    assert_successful_response(response)
  end

  def test_successful_update_subscription_billing_address
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert_successful_response(response)

    assert response = @gateway.update(response.authorization, nil,
      { order_id: generate_unique_id, setup_fee: 100, billing_address: address, email: 'someguy1232@fakeemail.net' })

    assert_successful_response(response)
  end

  def test_successful_delete_subscription
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert response.success?
    assert response.test?

    assert response = @gateway.unstore(response.authorization, order_id: generate_unique_id)
    assert response.success?
    assert response.test?
  end

  def test_successful_delete_subscription_with_elo
    assert response = @gateway.store(@elo_credit_card, @subscription_options)
    assert response.success?
    assert response.test?

    assert response = @gateway.unstore(response.authorization, order_id: generate_unique_id)
    assert response.success?
    assert response.test?
  end

  def test_successful_retrieve_subscription
    assert response = @gateway.store(@credit_card, @subscription_options)
    assert response.success?
    assert response.test?

    assert response = @gateway.retrieve(response.authorization, order_id: generate_unique_id)
    assert response.success?
    assert response.test?
  end

  def test_3ds_enroll_request_via_purchase
    assert response = @gateway.purchase(1202, @three_ds_enrolled_card, @options.merge(payer_auth_enroll_service: true))
    assert_equal '475', response.params['reasonCode']
    assert !response.params['acsURL'].blank?
    assert !response.params['paReq'].blank?
    assert !response.params['xid'].blank?
    assert !response.success?
  end

  def test_3ds_enroll_request_via_authorize
    assert response = @gateway.authorize(1202, @three_ds_enrolled_card, @options.merge(payer_auth_enroll_service: true))
    assert_equal '475', response.params['reasonCode']
    assert !response.params['acsURL'].blank?
    assert !response.params['paReq'].blank?
    assert !response.params['xid'].blank?
    assert !response.success?
  end

  def test_successful_3ds_requests_with_unenrolled_card
    assert response = @gateway.purchase(1202, @three_ds_unenrolled_card, @options.merge(payer_auth_enroll_service: true))
    assert response.success?

    assert response = @gateway.authorize(1202, @three_ds_unenrolled_card, @options.merge(payer_auth_enroll_service: true))
    assert response.success?
  end

  # to create a valid pares, use the test credentials to request `test_3ds_enroll_request_via_purchase` with debug=true.
  # Extract this XML and generate an accessToken. Using this access token to create a form, visit the stepUpURL provided
  # and check the network exchange in the browser dev console for a CCA, which will contain a usable PaRes. Documentation for this feature
  # can be found at https://docs.cybersource.com/content/dam/new-documentation/documentation/en/fraud-management/payer-auth/so/payer-auth-so.pdf
  def test_successful_3ds_validate_purchase_request
    assert response = @gateway.purchase(1202, @three_ds_enrolled_card, @options.merge(payer_auth_validate_service: true, pares: pares))
    assert_equal '100', response.params['reasonCode']
    assert_equal '0', response.params['authenticationResult']
    assert response.success?
  end

  def test_failed_3ds_validate_purchase_request
    assert response = @gateway.purchase(1202, @three_ds_invalid_card, @options.merge(payer_auth_validate_service: true, pares: pares))
    assert_equal '476', response.params['reasonCode']
    assert !response.success?
  end

  def test_successful_3ds_validate_authorize_request
    assert response = @gateway.authorize(1202, @three_ds_enrolled_card, @options.merge(payer_auth_validate_service: true, pares: pares))
    assert_equal '100', response.params['reasonCode']
    assert_equal '0', response.params['authenticationResult']
    assert response.success?
  end

  def test_failed_3ds_validate_authorize_request
    assert response = @gateway.authorize(1202, @three_ds_invalid_card, @options.merge(payer_auth_validate_service: true, pares: pares))
    assert_equal '476', response.params['reasonCode']
    assert !response.success?
  end

  def test_successful_authorize_via_normalized_3ds2_fields
    options = @options.merge(
      three_d_secure: {
        version: '2.0',
        eci: '05',
        cavv: 'jJ81HADVRtXfCBATEp01CJUAAAA=',
        xid: 'BwABBJQ1AgAAAAAgJDUCAAAAAAA=',
        ds_transaction_id: '97267598-FAE6-48F2-8083-C23433990FBC',
        cavv_algorithm: 1,
        enrolled: 'Y',
        authentication_response_status: 'Y'
      },
      commerce_indicator: 'vbv'
    )

    response = @gateway.authorize(@amount, @three_ds_enrolled_card, options)
    assert_successful_response(response)
  end

  def test_successful_mastercard_authorize_via_normalized_3ds2_fields
    options = @options.merge(
      three_d_secure: {
        version: '2.0',
        eci: '05',
        cavv: 'jJ81HADVRtXfCBATEp01CJUAAAA=',
        xid: 'BwABBJQ1AgAAAAAgJDUCAAAAAAA=',
        ds_transaction_id: '97267598-FAE6-48F2-8083-C23433990FBC'
      },
      commerce_indicator: 'spa',
      collection_indicator: 2
    )

    response = @gateway.authorize(@amount, @three_ds_enrolled_mastercard, options)
    assert_successful_response(response)
  end

  def test_successful_purchase_via_normalized_3ds2_fields
    options = @options.merge(
      three_d_secure: {
        version: '2.0',
        eci: '05',
        cavv: 'jJ81HADVRtXfCBATEp01CJUAAAA=',
        xid: 'BwABBJQ1AgAAAAAgJDUCAAAAAAA=',
        ds_transaction_id: '97267598-FAE6-48F2-8083-C23433990FBC'
      }
    )

    response = @gateway.purchase(@amount, @three_ds_enrolled_card, options)
    assert_successful_response(response)
  end

  def test_successful_mastercard_purchase_via_normalized_3ds2_fields
    options = @options.merge(
      three_d_secure: {
        version: '2.0',
        eci: '05',
        cavv: 'jJ81HADVRtXfCBATEp01CJUAAAA=',
        xid: 'BwABBJQ1AgAAAAAgJDUCAAAAAAA=',
        ds_transaction_id: '97267598-FAE6-48F2-8083-C23433990FBC'
      },
      commerce_indicator: 'spa',
      collection_indicator: 2
    )

    response = @gateway.purchase(@amount, @three_ds_enrolled_mastercard, options)
    assert_successful_response(response)
  end

  def test_successful_first_cof_authorize
    @options[:stored_credential] = {
      initiator: 'cardholder',
      reason_type: '',
      initial_transaction: true,
      network_transaction_id: ''
    }
    @options[:commerce_indicator] = 'internet'
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_successful_subsequent_unscheduled_cof_authorize
    @options[:stored_credential] = {
      initiator: 'merchant',
      reason_type: 'unscheduled',
      initial_transaction: false,
      network_transaction_id: '016150703802094'
    }
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_successful_recurring_cof_authorize
    @options[:stored_credential] = {
      initiator: 'merchant',
      reason_type: 'recurring',
      initial_transaction: false,
      network_transaction_id: ''
    }
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_successful_subsequent_recurring_cof_authorize
    @options[:stored_credential] = {
      initiator: 'merchant',
      reason_type: 'recurring',
      initial_transaction: false,
      network_transaction_id: '016150703802094'
    }
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_successful_subsequent_installment_cof_authorize
    @options[:stored_credential] = {
      initiator: 'merchant',
      reason_type: 'installment',
      initial_transaction: false,
      network_transaction_id: '016150703802094'
    }
    assert response = @gateway.authorize(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_successful_subsequent_unscheduled_cof_purchase
    @options[:stored_credential] = {
      initiator: 'merchant',
      reason_type: 'unscheduled',
      initial_transaction: false,
      network_transaction_id: '016150703802094'
    }
    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_successful_response(response)
  end

  def test_invalid_field
    @options = @options.merge({
      address: {
        address1: 'Unspecified',
        city: 'Unspecified',
        state: 'NC',
        zip: '1234567890',
        country: 'US'
      }
    })

    assert response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal 'One or more fields contains invalid data: c:billTo/c:postalCode', response.message
  end

  def pares
    <<~PARES
      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
    PARES
  end

  def test_successful_verify_with_elo
    response = @gateway.verify(@elo_credit_card, @options)
    assert_successful_response(response)
  end

  def test_verify_credentials
    assert @gateway.verify_credentials

    gateway = CyberSourceGateway.new(login: 'an_unknown_login', password: 'unknown_password')
    assert !gateway.verify_credentials
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match '1.00', response.params['amount']
    assert_equal 'Successful transaction', response.message
  end

  def test_successful_verify_zero_amount_visa
    @options[:zero_amount_auth] = true
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match '0.00', response.params['amount']
    assert_equal 'Successful transaction', response.message
  end

  def test_successful_verify_zero_amount_master
    @options[:zero_amount_auth] = true
    response = @gateway.verify(@master_credit_card, @options)
    assert_success response
    assert_match '0.00', response.params['amount']
    assert_equal 'Successful transaction', response.message
  end

  private

  def assert_successful_response(response)
    assert_equal 'Successful transaction', response.message
    assert_success response
    assert response.test?
  end
end

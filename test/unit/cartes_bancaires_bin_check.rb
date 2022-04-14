require 'csv'
require 'pry'

require 'bundler/setup'
require 'active_merchant'

class CartesBancairesBinCheck
  include ActiveMerchant::Billing::CreditCardMethods

  class CreditCard
    include ActiveMerchant::Billing::CreditCardMethods
  end

  CSV.open("/Users/leahriffell/active_merchant/lib/active_merchant/billing/cartes_bancaires_bins_check.csv", "w") do |csv|
    csv << ["bin_number",	"bin_length",	"cartes_bancaires_network", "active_merchant_network", "bin_to_store_in_active_merchant"]

    CSV.foreach("/Users/leahriffell/active_merchant/lib/active_merchant/billing/cartes_bancaires-bins.csv", headers: true) do |row|
      cc_number_length = 16

      cc_number = row[0].ljust(cc_number_length,'0')
      active_merchant_brand = CreditCard.brand?(cc_number)
      row[3] = active_merchant_brand || 'unknown'
      row[4] = row[0][0..5]

      csv << row
    end
  end

  # Below was for checking to see if the char count of bin length impacts how a card gets classified
  # no brand discrepancy if maxing out at 6 vs. 8 vs. full chars

  # discrepancy = 0

  # csv << ["bin_number",	"bin_length",	"cartes_bancaires_network", "active_merchant_network", "active_merchant_network_max_chars", "max_char_discrepancy"]
    # CSV.foreach("/Users/leahriffell/active_merchant/lib/active_merchant/billing/cartes_bancaires-bins.csv", headers: true) do |row|
    #   cc_number_length = 16
    #   cc_number = row[0].ljust(cc_number_length,'0')
    #   active_merchant_brand = CreditCard.brand?(cc_number)
    #   row[3] = active_merchant_brand || 'unknown'

    #   cc_number_length = 16
    #   cc_number_max_chars = row[0][0..5].ljust(cc_number_length,'0')
    #   active_merchant_max_chars_brand = CreditCard.brand?(cc_number_max_chars)
    #   row[4] = active_merchant_max_chars_brand || 'unknown'

    #   if active_merchant_brand != active_merchant_max_chars_brand
    #     row[5] = "DISCREPANCY"
    #     discrepancy += 1
    #   end

    #   csv << row
  #   end
  #   puts discrepancy
  # end
end

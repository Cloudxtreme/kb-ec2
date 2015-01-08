require 'rubygems'
require 'ruby-jmeter'

# YAY - DSL not that useful for REST APIs ... but at least runs on the Cloud :)
module RubyJmeter
  class RegularExpressionExtractor
    def initialize(params={})
      testname = params.kind_of?(Array) ? 'RegularExpressionExtractor' : (params[:name] || 'RegularExpressionExtractor')
      @doc = Nokogiri::XML(<<-EOS.strip_heredoc)
<RegexExtractor guiclass="RegexExtractorGui" testclass="RegexExtractor" testname="#{testname}" enabled="true">
  <stringProp name="RegexExtractor.useHeaders">#{(!! params[:headers]).to_s}</stringProp>
  <stringProp name="RegexExtractor.refname"/>
  <stringProp name="RegexExtractor.regex"/>
  <stringProp name="RegexExtractor.template"/>
  <stringProp name="RegexExtractor.default">#{params[:default].to_s}</stringProp>
  <stringProp name="RegexExtractor.match_number">#{(params[:match] || 1).to_s}</stringProp>
  #{"<stringProp name=\"Sample.scope\">params[:scope]</stringProp>" if params[:scope]}
  #{"<stringProp name=\"Sample.scope\">variable</stringProp>" if params[:variable]}
  #{"<stringProp name=\"Scope.variable\">params[:variable]</stringProp>" if params[:variable]}
</RegexExtractor>)
      EOS
      update params
      update_at_xpath params if params.is_a?(Hash) && params[:update_at_xpath]
    end
  end
end

#

root = 'http://127.0.0.1:8080'; root = 'http://54.148.66.206:8080'

if ENV['SSH_CONNECTION'] && ENV['LOGNAME'] == 'ubuntu' # inside EC2
root = 'http://172.31.17.96:8080'
end

kb = File.join(root, '/1.0/kb')

puts kb.inspect

THREADS = 50 # concurrency
DURATION = 4 * 60 * 60 # seconds

kb_headers = [
  { name: 'X-Killbill-ApiKey',    value: 'bob' },
  { name: 'X-Killbill-ApiSecret', value: 'lazar' },
  { name: 'X-Killbill-CreatedBy', value: 'demo' },
]

now = Time.now; now_str = now.strftime '%F-%T'

test do

  # KB Accept: XXX pooh-pooh: with_json

  auth username: 'admin', password: 'password'

  header [
    { name: 'Content-Type', value: 'application/json' },
  ] + kb_headers

  location_id_regex = "Location: http://.*/(.+)/?"

  # loop: 2, continue_forever: true, duration: 60 (sec) :

  threads THREADS, duration: DURATION do

    uuid = '${__UUID()}'
    counter = '${__counter(false)}'

    first, last = "John #{counter}", "Bill"
    account = {
      name: "#{first} #{last}",
      email: "johny#{counter}-#{now_str}@killbill.test",
      # externalKey: "john-#{now_str}-#{counter}",
      externalKey: "johny-#{uuid}",
      currency: 'USD'
    }

    once_only_controller do

      post name: :'Create Account',
           url: "#{kb}/accounts", raw_body: account.to_json do
        extract name: 'account_id', regex: location_id_regex, headers: true
      end

      get name: :'Visit Account', url: "#{kb}/accounts/${account_id}"

      stripe_payment_method = {
        # isDefault: true, only query !
        pluginName: 'killbill-stripe',
        pluginInfo: {
          properties: [
            { key: 'email', value: account[:email] },
            { key: 'description', value: now.to_s },
            { key: 'ccFirstName', value: first },
            { key: 'ccLastName',  value: last },
            { key: 'ccNumber', value: '4242424242424242' }, # VISA
            { key: 'ccExpirationYear', value: now.year + 1 },
            { key: 'ccExpirationMonth', value: '10' },
          ]
        }
      }

      puts stripe_payment_method.to_json

      # NOTE: URL parameters only works correctly with **raw_path: true**
      # ... otherwise RubyJmeter plays is smart and parses the passed URL

      post name: :'Stripe (Default) Payment Method',
           url: "#{kb}/accounts/${account_id}/paymentMethods?isDefault=true", raw_path: true,
           raw_body: stripe_payment_method.to_json do
        extract name: 'payment_method_id', regex: location_id_regex, headers: true
      end

      # NOTE: seems broken with Stripe + KB gem 3.1.12 http://git.io/zULU3A
      #put name: 'Set Default Payment Method',
      #    url: "#{kb}/accounts/${account_id}/paymentMethods/${payment_method_id}/setDefault"

    end

    1.times do |i|

      amount = (i + 1) * 10

      stripe_payment = {
        transactionType: 'AUTHORIZE',
        amount: amount,
        currency: 'USD',
        transactionExternalKey: "INV-#{i}-#{now_str}-#{uuid}-AUTH",
      }

      post name: :"Authorize Payment",
           url: "#{kb}/accounts/${account_id}/payments",
           raw_body: stripe_payment.to_json do
        # NOTE: from **/payments** we get a ending '/' e.g. Location:
        # http://54.148.66.206:8080/1.0/kb/payments/3a008cd2-4cc2-4168-a4ea-e4894c754424/
        extract name: 'payment_id', regex: location_id_regex, headers: true
      end

      stripe_payment = {
        transactionType: 'CAPTURE',
        amount: amount,
        currency: 'USD',
        transactionExternalKey: "INV-#{i}-#{now_str}-#{uuid}-CAPTURE",
      }

      post name: :"Capture Payment",
           url: "#{kb}/payments/${payment_id}",
           raw_body: stripe_payment.to_json do
      end

    end

    1.times do |i|

      amount = (i + 1) * 10

      stripe_payment = {
        transactionType: 'PURCHASE',
        amount: amount,
        currency: 'USD',
        transactionExternalKey: "INV-#{i}-#{now_str}-#{uuid}-PURCHASE",
      }

      post name: :"Purchase Payment",
           url: "#{kb}/accounts/${account_id}/payments",
           raw_body: stripe_payment.to_json do
        #extract name: 'payment_id', regex: location_id_regex, headers: true
      end

    end

  end

end.run(
  #path: '/usr/share/jmeter/bin/',
  file: "jmeter_#{now_str}.jmx",
  log:  "jmeter_#{now_str}.log",
  jtl:  "result_#{now_str}.jtl",
)

require 'rubygems'
require 'ruby-jmeter'

# YAY - DSL not that useful for REST APIs ... but at least runs on the Cloud :)
module RubyJmeter
  class RegularExpressionExtractor
    def initialize(params={})
      options = params.is_a?(Hash) ? params : {}
      testname = options[:name] || 'RegularExpressionExtractor'
      @doc = Nokogiri::XML(<<-EOS.strip_heredoc)
<RegexExtractor guiclass="RegexExtractorGui" testclass="RegexExtractor" testname="#{testname}" enabled="true">
  <stringProp name="RegexExtractor.useHeaders">#{!! options[:headers]}</stringProp>
  <stringProp name="RegexExtractor.refname"/>
  <stringProp name="RegexExtractor.regex"/>
  <stringProp name="RegexExtractor.template"/>
  <stringProp name="RegexExtractor.default">#{options[:default]}</stringProp>
  <stringProp name="RegexExtractor.match_number">#{options[:match] || 1}</stringProp>
  #{"<stringProp name=\"Sample.scope\">options[:scope]</stringProp>" if options[:scope]}
  #{"<stringProp name=\"Sample.scope\">variable</stringProp>" if options[:variable]}
  #{"<stringProp name=\"Scope.variable\">options[:variable]</stringProp>" if options[:variable]}
</RegexExtractor>)
      EOS
      update params
      update_at_xpath params if params.is_a?(Hash) && params[:update_at_xpath]
    end
  end

  class SaveResponsesToAFile
    def initialize(params={})
      options = params.is_a?(Hash) ? params : {}
      testname = params[:name] || 'SaveResponsesToAFile'
      @doc = Nokogiri::XML(<<-EOS.strip_heredoc)
<ResultSaver guiclass="ResultSaverGui" testclass="ResultSaver" testname="#{testname}" enabled="true">
  <stringProp name="FileSaver.filename">#{options[:filename]}</stringProp>
  <stringProp name="FileSaver.variablename">#{options[:variable]}</stringProp>
  <boolProp name="FileSaver.addTimstamp">#{!! options[:timestamp]}</boolProp>
  <boolProp name="FileSaver.successonly">#{!! options[:success_only]}</boolProp>
  <boolProp name="FileSaver.errorsonly">#{!! options[:errors_only]}</boolProp>
  <boolProp name="FileSaver.skipautonumber">#{! options.fetch(:auto_number) { true }}</boolProp>
  <boolProp name="FileSaver.skipsuffix">#{! options.fetch(:suffix) { true }}</boolProp>
</ResultSaver>)
      EOS
      update params
      update_at_xpath params if params.is_a?(Hash) && params[:update_at_xpath]
    end
  end
end

module RubyJmeter
  class DSL
    def post_thread_group(params={}, &block)
      node = RubyJmeter::PostThreadGroup.new(params)
      attach_node(node, &block)
    end
    alias tear_down_thread_group post_thread_group
    def setup_thread_group(params={}, &block)
      node = RubyJmeter::SetupThreadGroup.new(params)
      attach_node(node, &block)
    end
    alias set_up_thread_group setup_thread_group
  end

  class AroundThreadGroup
    attr_accessor :doc
    include Helper

    def initialize(params={})
      options = params.is_a?(Hash) ? params : {}
      testname = options[:name] || 'tearDown Thread Group'
      testname = params.kind_of?(Array) ? 'ThreadGroup' : (params[:name] || 'tearDown Thread Group')
      @doc = Nokogiri::XML(<<-EOS.strip_heredoc)
<#{element_name} guiclass="#{gui_class}" testclass="#{test_class}" testname="#{testname}" enabled="true">
  <stringProp name="ThreadGroup.on_sample_error">continue</stringProp>
  <elementProp name="ThreadGroup.main_controller" elementType="LoopController" guiclass="LoopControlPanel" testclass="LoopController" testname="#{testname}" enabled="true">
    <boolProp name="LoopController.continue_forever">false</boolProp>
    <stringProp name="LoopController.loops">1</stringProp>
  </elementProp>
  <stringProp name="ThreadGroup.num_threads">1</stringProp>
  <stringProp name="ThreadGroup.ramp_time">1</stringProp>
  <longProp name="ThreadGroup.start_time">1366415241000</longProp>
  <longProp name="ThreadGroup.end_time">1366415241000</longProp>
  <boolProp name="ThreadGroup.scheduler">false</boolProp>
  <stringProp name="ThreadGroup.duration"/>
  <stringProp name="ThreadGroup.delay"/>
</#{element_name}>)
      EOS
      update params
      update_at_xpath params if params.is_a?(Hash) && params[:update_at_xpath]
    end

    def element_name; raise 'not implemented' end

    def test_class; element_name end
    def gui_class; "#{element_name}Gui" end

  end

  class PostThreadGroup < AroundThreadGroup
    def element_name; 'PostThreadGroup' end
  end

  class SetupThreadGroup < AroundThreadGroup
    def element_name; 'SetupThreadGroup' end
  end

end


#

root = 'http://127.0.0.1:8080'
# e.g. export KB_URL="http://172.31.17.96:8080" in ~/.profile
root = ENV['KB_URL'] if ENV['KB_URL']

kb = File.join(root, '/1.0/kb')

puts kb.inspect

THREADS = 100 # concurrency
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

  threads THREADS.to_i, duration: DURATION.to_i do

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

  threads_url = "#{root}/1.0/threads?pretty=true"
  metrics_url = "#{root}/1.0/metrics?pretty=true"

  set_up_thread_group do

    save_responses_to_a_file filename: "setup_#{now_str}_", timestamp: false

    get name: :'Threads', url: threads_url

    get name: :'Metrics', url: metrics_url

  end


  tear_down_thread_group do

    save_responses_to_a_file filename: "teardown_#{now_str}_", timestamp: false

    get name: :'Threads', url: threads_url

    get name: :'Metrics', url: metrics_url

    random_timer 1000 # constant delay in millis
    get name: :'Metrics', url: metrics_url

    random_timer 1000 # constant delay in millis
    get name: :'Metrics', url: metrics_url

    random_timer 3000 # constant delay in millis
    get name: :'Metrics', url: metrics_url

  end

end.run(
  #path: '/usr/share/jmeter/bin/',
  file: "jmeter_#{now_str}.jmx",
  log:  "jmeter_#{now_str}.log",
  jtl:  "result_#{now_str}.jtl",
)


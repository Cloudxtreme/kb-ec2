
#2015-02-11 21:34:45,433 [Thread-5] INFO  o.k.b.k.0.1.2 - [stripe-plugin] [ActiveMerchant::Billing::StripeGateway] --> 200 OK (1372 18.0520s)
#2015-02-11 21:34:45,433 [Thread-5] INFO  o.k.b.k.0.1.2 - [stripe-plugin] [ActiveMerchant::Billing::StripeGateway] connection_attempt=1 connection_request_time=18.0770s connection_msg="success"
#2015-02-11 21:34:45,433 [Thread-5] INFO  o.k.b.k.0.1.2 - [stripe-plugin] [ActiveMerchant::Billing::StripeGateway] connection_request_total_time=18.0770s
#
#2015-02-11 21:34:45,437 [Thread-5] INFO  o.k.b.k.0.1.2 - [stripe-plugin] [ActiveMerchant::Billing::StripeGateway] --> 200 OK (1372 8.5260s)
#2015-02-11 21:34:45,437 [Thread-5] INFO  o.k.b.k.0.1.2 - [stripe-plugin] [ActiveMerchant::Billing::StripeGateway] connection_attempt=1 connection_request_time=8.6220s connection_msg="success"
#2015-02-11 21:34:45,437 [Thread-5] INFO  o.k.b.k.0.1.2 - [stripe-plugin] [ActiveMerchant::Billing::StripeGateway] connection_request_total_time=8.6220s

#2015-02-18 16:27:50,073 [Thread-5] INFO  o.k.b.k.0.1.3.SNAPSHOT - [litle-plugin] [ActiveMerchant::Billing::LitleGateway] --> 200 OK (520 1.7390s)
#2015-02-18 16:27:50,073 [Thread-5] INFO  o.k.b.k.0.1.3.SNAPSHOT - [litle-plugin] [ActiveMerchant::Billing::LitleGateway] connection_attempt=1 connection_request_time=1.8120s connection_msg="success"
#2015-02-18 16:27:50,073 [Thread-5] INFO  o.k.b.k.0.1.3.SNAPSHOT - [litle-plugin] [ActiveMerchant::Billing::LitleGateway] connection_request_total_time=1.8130s

#18:00:56.582 [Thread-5] INFO  org.kill-bill.billing.killbill-platform-osgi-bundles-jruby-1.0.1.3.SNAPSHOT - [stripe-plugin] [ActiveMerchant::Billing::StripeGateway] connection_request_total_time=2.5950s

raise 'no FILE arg given' unless file_path = ARGV.last

REQUEST_TOTAL_TIME_RE = /(?:(\d{4}-\d{2}-\d{2}[\s])?\d{2}:\d{2}:\d{2}[,.]\d*).*?\[(ActiveMerchant::Billing::.*?)\].*?connection_request_total_time=([\d\.]+s)/

RequestTime = Struct.new(:timestamp, :gateway_name, :total_time) do
  def parse_total_time
    time = total_time
    time = time[0...-1] if time[-1, 1] == 's'
    time.to_f
  end
  def parse_timestamp; require 'date'
    DateTime.parse(timestamp).to_time
  end
end

@@lines = 0

def parse_line(line, request_times)
  @@lines += 1

  if match = line.match(REQUEST_TOTAL_TIME_RE)
    request_times << RequestTime.new(match[1], match[2], match[3])
  end
end

request_times = []

file = File.open(file_path, 'r+')

file.each_line do |line|
  STDERR.write '.' if parse_line(line, request_times) && @@lines % 100 == 0
end

STDERR.write " parsed #{@@lines} lines\n" # STDERR.write "\n"

file.close


request_times_by_gateway = Hash.new { |hash, name| hash[name] = [] }
request_times.each { |req_time| request_times_by_gateway[ req_time.gateway_name ] << req_time }

puts "\n"

class Array
  def mean
	  inject(0) { |sum, x| sum += x } / size.to_f
	end
	def median
	  return nil if empty?
	  array = sort; m_pos = array.size / 2
	  array.size % 2 == 1 ? array[m_pos] : array[m_pos-1..m_pos].mean
	end
end

class String
  def underscore
    word = self.dup
    word.gsub!(/::/, '/')
    word.gsub!(/([A-Z]+)([A-Z][a-z])/,'\1_\2')
    word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
    word.tr!("-", "_"); word.downcase!
    word
  end
end

def graph_results_gruff(gateway_name, request_times)
  begin
    require 'gruff'
  rescue LoadError => e
    warn e.inspect
    return nil
  end

  min_time = request_times.first.parse_timestamp
  max_time = min_time
  data = []; labels = {}

  request_times.each do |req_time|
    time = req_time.parse_timestamp
    min_time = time if min_time > time
    max_time = time if max_time < time
  end

  duration_mins = (max_time - min_time) / 60 # ~ 240 (4h test)
  val = 0; step = 30
  while val <= duration_mins
    labels[ val ] = "#{val}m"; val += step
  end

  request_times.each do |req_time|
    time = req_time.parse_timestamp
    x = (time - min_time) / 60
    data << [ req_time.parse_total_time, x ]
  end

  file_name = gateway_name.underscore
  if i = file_name.index('/')
    file_name = file_name[ i + 1..-1 ]
  end

  g = Gruff::Area.new(800)
  g.title = gateway_name
  g.labels = labels
  data.each { |d| g.data(d[0], d[1]) }

  g.write("./#{file_name}.png")
end

def graph_results(gateway_name, request_times)
  min_time = request_times.first.parse_timestamp
  max_time = min_time
  data = []

  request_times.each do |req_time|
    time = req_time.parse_timestamp
    min_time = time if min_time > time
    max_time = time if max_time < time
  end

  request_times.each do |req_time|
    time = req_time.parse_timestamp
    x = ((time - min_time) / 60).round(3)
    data << [ x, req_time.parse_total_time ]
  end

  require 'tempfile'
  file = Tempfile.new('gnuplot-data')
  data.each { |d| file.write "#{d[0]} \t #{d[1]}" }
  file.flush

  file_data = file.path

  file_name = gateway_name.underscore
  if i = file_name.index('/')
    file_name = file_name[ i + 1..-1 ]
  end
  file_name = File.expand_path(file_name)

  commands = %Q(
    set title "#{gateway_name}"
    set terminal svg
    set output "#{file_name}.svg"

    set xlabel "t(m)"
    set ylabel "r(s)"
    set grid
    plot "#{file_data}" title ""
  )
  IO.popen("gnuplot", "w") { |io| io.puts commands }

  file.close

  puts "# graphed using gnuplot at #{file_name}"
end

request_times_by_gateway.each do |gateway_name, request_times|
  times = request_times.map { |req_time| req_time.parse_total_time }
  puts "#{gateway_name} connection_request_total_time (#{times.size} requests) mean = #{times.mean} median = #{times.median} min = #{times.min} max = #{times.max}"
  puts "\n"

  #graph_results(gateway_name, request_times)
end

=begin
def print_report(errors_count_map, error_msgs_map, file_path)
  puts "# parsed errors report from #{file_path} (size: #{File.size(file_path)})\n\n"
  puts "\n"

  error_label = ''
  count_label = 'Count'

  longest_type = error_label.size; longest_count = count_label.size; total = 0
  errors_count_map.each do |type, count|
    if longest_type < type.length
      longest_type = type.length
    end
    if longest_count < count.to_s.length
      longest_count = count.to_s.length
    end
    total += count
  end

  puts "| #{''.rjust(longest_type + 1, ' ')} | #{count_label.rjust(longest_count, ' ')} |"
  puts "| #{''.rjust(longest_type + 1, '-')} | #{'-'.rjust(longest_count, '-')} |"

  errors_count_map.each do |type, count|
    puts "| #{type.rjust(longest_type + 1)} | #{count.to_s.rjust(longest_count)} |"
  end

  puts "| #{'TOTAL'.rjust(longest_type + 1)} | #{total.to_s.rjust(longest_count)} |"

  puts "\n\n"; i = 0
  error_msgs_map.each do |type, messages|
    puts "\n\n#{i += 1}. #{type} messages:\n\n"
    messages.each { |msg| puts "  #{msg.to_s(4)}" }
  end
end
=end

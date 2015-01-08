
raise 'no FILE arg given' unless file_path = ARGV.last

# 2014-12-18 07:45:59,840 [http-bio-8080-exec-72] WARN  o.k.b.j.mappers.ExceptionMapperBase - Bad request
# org.killbill.billing.payment.api.PaymentApiException: Failed to retrieve payment plugin info for payment ...
EXCEPTION_RE = /^.*?\s?([Cc]aused by.*?)?([^\s]+?Exception|Error[^\s]?):\s*?(.*)/

class ExceptionStruct
  def initialize(message); @message = message end

  attr_reader :message
  def causes; @causes ||= [] end

  def to_s(indent_causes = 2)
    return message if causes.empty?
    s = ' ' * indent_causes
    "#{message}\n#{s}#{causes.join("\n#{s}")}"
  end
end

@@last_exception = nil

def parse_line(line, errors_count_map, error_msgs_map)
  if match = line.match(EXCEPTION_RE)

    line_lstrip = line.lstrip
    return nil if line_lstrip != line && line_lstrip.start_with?('at ')

    #puts match.inspect

    caused_by = match[1]
    exception_type = match[2].strip
    exception_mess = match[3].strip

    if caused_by # || exception_type =~ /Caused by:/i
      cause_exception = "#{caused_by}#{exception_type}: #{exception_mess}"
      if @@last_exception
        @@last_exception.causes << cause_exception
      else
        warn "missed exception for cause: #{exception_type}: #{exception_mess}"
      end
    else
      count = ( errors_count_map[ exception_type ] ||= 0 )
      errors_count_map[ exception_type ] = count + 1

      ( error_msgs_map[ exception_type ] ||= [] ) <<
        ( @@last_exception = ExceptionStruct.new(exception_mess) )
    end
  end
end

errors_count_map, error_msgs_map = {}, {}

file = File.open(file_path, 'r+')

file.each_line do |line|
  STDERR.write '.' if parse_line(line, errors_count_map, error_msgs_map)
end
STDERR.write "\n"

file.close

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

print_report(errors_count_map, error_msgs_map, file_path)

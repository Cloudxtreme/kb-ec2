
raise 'no .jtl given' unless jtl_path = ARGV.last

raise "'#{jtl_path}' is not a file!" unless File.file?(jtl_path)
raise "'#{jtl_path}' does not end with .jtl" if File.extname(jtl_path) != '.jtl'

command = 'JMeterPluginsCMD.sh'

if ENV['JMETER_HOME']
  command = File.join(ENV['JMETER_HOME'], 'lib/ext', command)
else
  if `which #{command}`.strip.empty?
    raise "#{command} not found, try setting JMETER_HOME"
  end
end

options = [ '--tool Reporter' ]
options << "--input-jtl #{jtl_path}"

report_dir = File.dirname(jtl_path)

# def normalize_jtl(jtl)
#
# end

def snake_case(str)
  str.gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
      gsub(/([a-z\d])([A-Z])/,'\1_\2').
      tr('-', '_').
      gsub(/\s/, '_').
      gsub(/__+/, '_').
      downcase
end

img_width, img_height = 1200, 900

PLUGINS = {
  'AggregateReport' => '--generate-csv',
  'SynthesisReport' => '--generate-csv',

  'ResponseTimesDistribution' => "--width #{img_width} --height #{img_height} --generate-png",
  'ResponseTimesOverTime' => "--width #{img_width} --height #{img_height} --generate-png",
  'ResponseCodesPerSecond' => "--width #{img_width} --height #{img_height} --generate-png",
  'TransactionsPerSecond' => "--width #{img_width} --height #{img_height} --generate-png",

  # 'LatenciesOverTime' => "--width #{img_width} --height #{img_height} --generate-png",
}

silence = true

# JMeterPluginsCMD.sh --tool Reporter --generate-csv aggregate_report.csv --plugin-type AggregateReport
PLUGINS.each do |plugin, opts|
  report_file = 'report_' + snake_case(plugin).sub('_report', '')
  report_file += ( opts.index('generate-csv') ? '.csv' : '.png' )
  report_file = File.join(report_dir, report_file)
  cmd = "#{command} #{options.join(' ')} #{opts} #{report_file} --plugin-type #{plugin}"
  puts cmd
  system silence ? "#{cmd} > /dev/null" : cmd
end

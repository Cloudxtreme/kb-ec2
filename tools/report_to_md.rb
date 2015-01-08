
raise 'no FILE arg given' unless file_path = ARGV.last

require 'csv'

header = [ '', '#count', 'average', 'median', '90%', 'min', 'max', 'errors', 'bandwidth' ]
rows = []

max_column_size = header.map { |h| h.to_s.size }

CSV.foreach(file_path, col_sep: ',', row_sep: :auto, headers: true) do |row|
  rows << ( arr = [] )
  arr << row['sampler_label']
  arr << row['aggregate_report_count'].to_i
  arr << row['average'].to_i
  arr << row['aggregate_report_median'].to_i
  arr << row['aggregate_90%_line'].to_i
  arr << row['aggregate_report_min'].to_i
  arr << row['aggregate_report_max'].to_i
  arr << ( sprintf( '%.5f', row['aggregate_report_error%'].to_f ) + '%' )
  # when the throughput is saved to a CSV file, it is expressed in requests/second,
  # i.e. 30.0 requests/minute is saved as 0.5 :
  arr << ( row['aggregate_report_bandwidth'].to_f.round(2).to_s + '/s' )

  arr.each_with_index do |el, i|
    max_column_size[i] = el.to_s.size if max_column_size[i].to_i < el.to_s.size
  end
end

buff = ''; delim = ''
header.each_with_index do |h, i|
  longest = max_column_size[i].to_i
  buff << "| #{h.rjust(longest, ' ')} "
  delim << "| #{'-'.rjust(longest, '-')} "
end
buff << '|'; delim << '|'
#buff << ("\n" + ( '-' * buff.length ) + "\n")
buff << "\n" << delim << "\n"

rows.each do |row|
  row.each_with_index do |r, i|
    longest = max_column_size[i].to_i
    buff << "| #{r.to_s.rjust(longest, ' ')} "
  end
  buff << "|\n"
end

puts buff
require 'savon'
require "mysql2"
DB_HOST = "208.65.111.153"
DB_USER = "reports"
DB_PASSWORD = "saobn29rla1SC"
DB = "porta-billing"
TIME_OUT = 43000
@@client = Mysql2::Client.new(:host => DB_HOST, :username => DB_USER, :password=> DB_PASSWORD, :database => DB, :wait_timeout => TIME_OUT, :interactive_timeout => TIME_OUT)
class WeekTrafficsController
  def perform
    @from_date = Time.now - 1.days
    @to_date = Time.now
  	#@from_date = getFromDate()
    #@to_date = (Time.new(@from_date[0..3].to_i,@from_date[5..6].to_i,@from_date[8..9].to_i,@from_date[11..12].to_i,@from_date[14..15].to_i,@from_date[17..18].to_i) + 1.days - 1.seconds).to_s
    WeekTraffic.destroy WeekTraffic.all.map { |w| w}
    
    @week_traffic_refined = {}
    rate = convertToUSD("BRL")
    sql = "SELECT customer, calldate, count(CLD), sum(revenue), sum(cost), sum(margin), sum(minutes) FROM v_CDR_Accounts WHERE revenue > 0 and calldate between '#{@from_date}' and '#{@to_date}' and customer not like 'zzz%' group by date_format((calldate + interval 2 hour),_utf8'%Y-%m-%d');"
    rs = @@client.query(sql)
    puts "DATEEEEE"
    puts @from_date
    puts @to_date
    rs.each do |row|
      puts "ROW"
      puts row.inspect
      day_traffic = WeekTraffic.find_by_calldate(row["calldate"].strftime("%Y-%m-%d"))
      puts day_traffic.inspect
      if not day_traffic.eql?(nil)
        day_traffic.update_attributes(:revenue => day_traffic[:revenue] + row["revenue"], :cost => day_traffic[:cost] + row["cost"], :margin => day_traffic[:margin] + row["margin"], :minutes => day_traffic[:minutes] + row["minutes"])
      else          
        day_traffic = WeekTraffic.new(id: row["i_vendor"], name: row["vendor"], revenue: row["revenue"], cost: row["cost"] , margin: row["margin"], minutes: row["minutes"], asr: 0)
        day_traffic.save
      end
    end
  end

  private
  def convertToUSD(from)
    c=Savon.client(wsdl: "http://www.webservicex.net/CurrencyConvertor.asmx?WSDL")
    r=c.call(:conversion_rate, message: {'FromCurrency' => from, 'ToCurrency' => "USD"})
    return r.to_hash[:conversion_rate_response][:conversion_rate_result]
  end

  def getFromDate
    client_full_date = Time.now()
    utc_time = Time.now.utc
    final = utc_time.strftime("%Y-%m-%d %H-%M-%S")
    hours = client_full_date.strftime("%H-%M-%S")[0..1].to_i
    hours_difference = utc_time.strftime("%Y-%m-%d %H-%M-%S")[11..12].to_i - hours
    if (hours_difference) < 0
      final[8..9] = ((utc_time).strftime("%Y-%m-%d %H-%M-%S")[8..9].to_i - 1).to_s
      final[11..12] = '00'
    else
      final[11..12] = ((utc_time).strftime("%Y-%m-%d %H-%M-%S")[11..12].to_i - hours).to_s
    end
    final[11..12] = (sprintf '%02d', final[11..12].to_i).to_s
    final[13] = '-'
    final[14..15] = '00'
    final[16] = '-'
    final[17..18] = '00'
    final[19..22] = ' UTC'
    return final
  end
end

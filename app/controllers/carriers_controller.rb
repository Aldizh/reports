require 'savon'
require "mysql2"
DB_HOST = "208.65.111.153"
DB_USER = "reports"
DB_PASSWORD = "saobn29rla1SC"
DB = "porta-billing"
TIME_OUT = 43000
@@client = Mysql2::Client.new(:host => DB_HOST, :username => DB_USER, :password=> DB_PASSWORD, :database => DB, :wait_timeout => TIME_OUT, :interactive_timeout => TIME_OUT)
class CarriersController
  def perform
  	@from_date = getFromDate()
    @to_date = (Time.new(@from_date[0..3].to_i,@from_date[5..6].to_i,@from_date[8..9].to_i,@from_date[11..12].to_i,@from_date[14..15].to_i,@from_date[17..18].to_i) + 1.days - 1.seconds).to_s
    
    rate = convertToUSD("BRL")
    sql_usd = "select count(A.CLD), A.connect_time, D.i_customer, D.name AS 'customer', D.iso_4217, B.i_vendor, C.name AS 'vendor', sum(A.charged_quantity / 60.0) AS 'minutes', sum(A.charged_amount) as 'revenue', sum(B.charged_amount) AS 'cost', sum(A.charged_amount - B.charged_amount) as 'margin' from (Vendors C join CDR_Vendors B) join Customers D join CDR_Accounts A where (C.i_vendor = B.i_vendor) and (B.h323_conf_id = A.h323_conf_id) and (D.i_customer = A.i_customer) and (B.i_service = A.i_service) and A.connect_time between '#{@from_date}' and '#{@to_date}' and i_parent is NULL and D.iso_4217 like 'USD' and D.name not like 'zzz%' and A.charged_amount > 0 group by vendor;"
	rs_usd = @@client.query(sql_usd)
	sql_brl = "select count(A.CLD), A.connect_time, D.i_customer, D.name AS 'customer', D.iso_4217, B.i_vendor, C.name AS 'vendor', sum(A.charged_quantity / 60.0) AS 'minutes', sum(A.charged_amount) as 'revenue', sum(B.charged_amount) AS 'cost', sum(A.charged_amount - B.charged_amount) as 'margin' from (Vendors C join CDR_Vendors B) join Customers D join CDR_Accounts A where (C.i_vendor = B.i_vendor) and (B.h323_conf_id = A.h323_conf_id) and (D.i_customer = A.i_customer) and (B.i_service = A.i_service) and A.connect_time between '#{@from_date}' and '#{@to_date}' and i_parent is NULL and D.iso_4217 like 'BRL' and D.name not like 'zzz%' and A.charged_amount > 0 group by vendor;"
	rs_brl = @@client.query(sql_brl)

	sql_usd_res = "select count(A.CLD), A.connect_time, D.i_customer, D.name AS 'customer', D.iso_4217, B.i_vendor, C.name AS 'vendor', sum(A.charged_quantity / 60.0) AS 'minutes', sum(A.charged_amount) as 'revenue', sum(B.charged_amount) AS 'cost', sum(A.charged_amount - B.charged_amount) as 'margin' from (Vendors C join CDR_Vendors B) join Customers D join CDR_Customers A where (C.i_vendor = B.i_vendor) and (B.h323_conf_id = A.h323_conf_id) and (D.i_customer = A.i_customer) and (B.i_service = A.i_service) and A.connect_time between '#{@from_date}' and '#{@to_date}' and i_parent is NULL and D.iso_4217 like 'USD' and D.name not like 'zzz%' and A.charged_amount > 0 group by vendor;"
	rs_usd_res = @@client.query(sql_usd_res)
	sql_brl_res = "select count(A.CLD), A.connect_time, D.i_customer, D.name AS 'customer', D.iso_4217, B.i_vendor, C.name AS 'vendor', sum(A.charged_quantity / 60.0) AS 'minutes', sum(A.charged_amount) as 'revenue', sum(B.charged_amount) AS 'cost', sum(A.charged_amount - B.charged_amount) as 'margin' from (Vendors C join CDR_Vendors B) join Customers D join CDR_Customers A where (C.i_vendor = B.i_vendor) and (B.h323_conf_id = A.h323_conf_id) and (D.i_customer = A.i_customer) and (B.i_service = A.i_service) and A.connect_time between '#{@from_date}' and '#{@to_date}' and i_parent is NULL and D.iso_4217 like 'BRL' and D.name not like 'zzz%' and A.charged_amount > 0 group by vendor;"
	rs_brl_res = @@client.query(sql_brl_res)

	Carrier.destroy Carrier.all.map { |c| c}
	rs_usd.each do |row|
	    carrier = Carrier.find(row["i_vendor"])
		if carrier
		  carrier.update_attributes(:revenue => carrier[:revenue] + row["revenue"], :cost => carrier[:cost] + row["cost"], :margin => carrier[:margin] + row["margin"], :minutes => carrier[:minutes] + row["minutes"], :num_calls => carrier[:num_calls] + row["count(A.CLD)"])
		else	        
		  carrier = Carrier.new(id: row["i_vendor"], name: row["vendor"], revenue: row["revenue"], cost: row["cost"] , margin: row["margin"], minutes: row["minutes"], num_calls: row["count(A.CLD)"], asr: 0)
	      carrier.save
	    end       
	end
	rs_brl.each do |row|
		carrier = Carrier.find_by_id(row["i_vendor"])
		if carrier
		  carrier.update_attributes(:revenue => carrier[:revenue] + row["revenue"]*rate.to_f, :cost => carrier[:cost] + row["cost"]*rate.to_f, :margin => carrier[:margin] + row["margin"]*rate.to_f, :minutes => carrier[:minutes] + row["minutes"], :num_calls => carrier[:num_calls] + row["count(A.CLD)"])
		else	        
		  carrier = Carrier.new(id: row["i_vendor"], name: row["vendor"], revenue: row["revenue"]*rate.to_f, cost: row["cost"]*rate.to_f, margin: row["margin"]*rate.to_f, minutes: row["minutes"], num_calls: row["count(A.CLD)"], asr: 0)
	      carrier.save
	    end 
	end
	rs_usd_res.each do |row|
	    carrier = Carrier.find(row["i_vendor"])
		if carrier
		  carrier.update_attributes(:revenue => carrier[:revenue] + row["revenue"], :cost => carrier[:cost] + row["cost"], :margin => carrier[:margin] + row["margin"], :minutes => carrier[:minutes] + row["minutes"], :num_calls => carrier[:num_calls] + row["count(A.CLD)"])
		else	        
		  carrier = Carrier.new(id: row["i_vendor"], name: row["vendor"], revenue: row["revenue"], cost: row["cost"] , margin: row["margin"], minutes: row["minutes"], num_calls: row["count(A.CLD)"], asr: 0)
	      carrier.save
	    end     
	end
	rs_brl_res.each do |row|        
		carrier = Carrier.find(row["i_vendor"])
		if carrier
		  carrier.update_attributes(:revenue => carrier[:revenue] + row["revenue"]*rate.to_f, :cost => carrier[:cost] + row["cost"]*rate.to_f, :margin => carrier[:margin] + row["margin"]*rate.to_f, :minutes => carrier[:minutes] + row["minutes"], :num_calls => carrier[:num_calls] + row["count(A.CLD)"])
		else	        
		  carrier = Carrier.new(id: row["i_vendor"], name: row["vendor"], revenue: row["revenue"]*rate.to_f, cost: row["cost"]*rate.to_f, margin: row["margin"]*rate.to_f, minutes: row["minutes"], num_calls: row["count(A.CLD)"], asr: 0)
	      carrier.save
	    end 
	end
  end

  def getInfo
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

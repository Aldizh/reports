require 'savon'
require 'mysql2'
DB_HOST = "208.65.111.153"
DB_USER = "reports"
DB_PASSWORD = "saobn29rla1SC"
DB = "porta-billing"
TIME_OUT = 43000
class ResellersController
	def perform
		@resellers_hash = {}
	    @selected_resellers = {}
	  	@from_date = getFromDate()
	    @to_date = (Time.new(@from_date[0..3].to_i,@from_date[5..6].to_i,@from_date[8..9].to_i,@from_date[11..12].to_i,@from_date[14..15].to_i,@from_date[17..18].to_i) + 1.days - 1.seconds).to_s
	    Reseller.destroy Reseller.all.map { |r| r}
      	sql = "Select count(A.CLD), A.connect_time, D.i_customer, D.name AS customer, B.i_vendor, C.name AS 'vendor', sum(A.charged_quantity / 60) AS 'minutes', sum(A.charged_amount) AS 'revenue', sum(B.charged_amount) AS 'cost', sum(A.charged_amount - B.charged_amount) AS 'margin' from (((Vendors C join CDR_Vendors B) join Customers D) join CDR_Customers A) where ((C.i_vendor = B.i_vendor) and (B.h323_conf_id = A.h323_conf_id) and (D.i_customer = A.i_customer) and (B.i_service = B.i_service)) and A.connect_time between '#{@from_date}' and '#{@to_date}' and D.name not like 'zzz%' and i_parent is NULL group by D.name;"
	    rs = @@client.query(sql)
	    rs.each do |row|
			@resellers_hash["#{row["i_customer"]}"] = [row["revenue"], row["cost"] , row["margin"], row["minutes"], row["count(A.CLD)"], row["i_customer"], row["customer"]]
	    end
	    
	    @resellers_hash.each do |k, v|
	      sql_asr = "SELECT asr24hr FROM v_CDR_Customers_ASR WHERE i_customer like '#{v[5]}'" #for calculating asr of reseller
	      rs_asr = @@client.query(sql_asr)
	  
	      sql_next = "SELECT * FROM Customers WHERE i_parent like '#{v[5]}' group by i_parent"
	      rs_next = @@client.query(sql_next)
	      rs_next.each do |cus|
	        if cus["iso_4217"] != "USD"
	          rate = convertToUSD(cus["iso_4217"])
	        else
	          rate = 1
	        end
	        reseller = Reseller.find_by_name(v[6])
	        if  reseller
	          reseller.update_attributes(:revenue => reseller[:revenue] + v[0]*rate.to_f, :cost => reseller[:cost] + v[1]*rate.to_f, :margin => reseller[:margin] + v[2]*rate.to_f, :minutes => reseller[:revenue] + v[3], :num_calls => reseller[:num_calls] + v[4])
	        else
	          reseller = Reseller.new(id: v[5], name: v[6], revenue: v[0]*rate.to_f, cost: v[1]*rate.to_f, margin: v[2]*rate.to_f, minutes: v[3], num_calls: v[4], asr: rs_asr.first["asr24hr"].to_i) #asr value to replaced by rs_asr.first["asr24hr"].to_i
      		  reseller.save
	        end
	      end
	    end
	end

	private
	def convertToUSD(from)
		c=Savon.client(wsdl: "http://www.webservicex.net/CurrencyConvertor.asmx?WSDL")
		r=c.call(:conversion_rate, message: {'FromCurrency' => from, 'ToCurrency' => "USD"})
		return r.to_hash[:conversion_rate_response][:conversion_rate_result]
	end

	def getFromDate #converts the date to utc and starts from 00:00:00 utc time
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
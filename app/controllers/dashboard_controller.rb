require 'savon'
require "mysql2"
DB_HOST = "208.65.111.153"
DB_USER = "reports"
DB_PASSWORD = "saobn29rla1SC"
DB = "porta-billing"
TIME_OUT = 43000
@@client = Mysql2::Client.new(:host => DB_HOST, :username => DB_USER, :password=> DB_PASSWORD, :database => DB, :wait_timeout => TIME_OUT, :interactive_timeout => TIME_OUT)  
class DashboardController < ApplicationController
  before_filter :require_login
  def index
    @total_revenue_customers, @total_cost_customers, @total_minutes_customers, @total_calls_customers = 0,0,0,0
    @total_revenue_carriers, @total_cost_carriers, @total_minutes_carriers, @total_calls_carriers = 0,0,0,0
    @total_revenue_resellers, @total_cost_resellers, @total_minutes_resellers, @total_calls_resellers = 0,0,0,0

    #CUSTOMERS
    #=====================================================================================================================#
    @selected_customers = Customer.all
    @total_revenue_customers = @selected_customers.map(&:revenue).sum
    @total_cost_customers = @selected_customers.map(&:cost).sum
    @total_minutes_customers = @selected_customers.map(&:minutes).sum
    @total_calls_customers = @selected_customers.map(&:num_calls).sum


    #REELLERS
    #=====================================================================================================================#
    @selected_resellers = Reseller.all
    @total_revenue_resellers = @selected_resellers.map(&:revenue).sum
    @total_cost_resellers = @selected_resellers.map(&:cost).sum
    @total_minutes_resellers = @selected_resellers.map(&:minutes).sum
    @total_calls_resellers = @selected_resellers.map(&:num_calls).sum

    #CARRIERS
    #=====================================================================================================================#
    @selected_vendors = Carrier.all
    @total_revenue_carriers =  @selected_vendors.map(&:revenue).sum
    @total_cost_carriers =  @selected_vendors.map(&:cost).sum
    @total_margin_carriers =  @selected_vendors.map(&:margin).sum
    @total_minutes_carriers = @selected_vendors.map(&:minutes).sum
    @total_calls_carriers = @selected_vendors.map(&:num_calls).sum

    #also show the accumulated traffic for last week
    #=====================================================================================================================#
    @week_traffic_refined = WeekTraffic.all
  end

  def topCustomers
    @total_revenue, @total_cost, @total_minutes, @total_calls = 0,0,0,0
    if params['viewFrom']
      @from_date = Time.new(params['viewFrom']['from(1i)'], params['viewFrom']['from(2i)'], params['viewFrom']['from(3i)'])
    else
      @from_date = Time.now
    end
    if params['viewTo']
      @to_date = Time.new(params['viewTo']['to(1i)'], params['viewTo']['to(2i)'], params['viewTo']['to(3i)'])
    else
      @to_date = Time.now
    end
    @from_date = getFromDate()
    @to_date = (Time.new(@from_date[0..3].to_i,@from_date[5..6].to_i,@from_date[8..9].to_i,@from_date[11..12].to_i,@from_date[14..15].to_i,@from_date[17..18].to_i) + 1.days - 1.seconds).to_s
    #If selected a date
    #then call api and display info, might take a while
    #otherwise call local database
    #trick will be in between two different connections
    if not params[:sort_by]
      sql = "SELECT COUNT( v_CDR_Vendors.i_customer ) AS num_calls, v_CDR_Vendors.customer AS customer,
      v_CDR_Vendors.i_customer AS i_customer, MAX( v_CDR_Vendors.calldate ) as last_call , SUM(v_CDR_Vendors.seconds) AS minutes,
      iso_4217 AS currency, SUM( v_CDR_Vendors.revenue ) AS revenue, SUM( v_CDR_Vendors.cost ) AS cost, SUM( v_CDR_Vendors.margin ) AS margin,
      v_CDR_Customers_ASR.asr24hr AS asr
      FROM v_CDR_Vendors
      LEFT JOIN v_CDR_Customers_ASR ON ( v_CDR_Vendors.i_customer = v_CDR_Customers_ASR.i_customer )
      WHERE calldate between '#{@from_date}' and '#{@to_date}'
      GROUP BY v_CDR_Vendors.i_customer
      ORDER BY revenue DESC;"
      rs = @@client.query(sql)
      rs.each do |row|
        @resellers_hash["#{row["i_customer"]}"] = [row["revenue"], row["cost"] , row["margin"], row["minutes"], row["num_calls"], row["i_customer"], row["customer"]]
      end
      
      @resellers_hash.each do |k, v|
        if @selected.has_key?("#{v[6]}")
          @selected["#{v[6]}"][0] = v[0]
          @selected["#{v[6]}"][1] = v[1]
          @selected["#{v[6]}"][2] = v[2]
          @selected["#{v[6]}"][3] = v[3]
          @selected["#{v[6]}"][4] = v[4]
        else
          @selected["#{v[6]}"] = [v[0], v[1], v[2], v[3], v[4], 0, v[5]]
        end
      end
      Rails.cache.write('customer_sel', @selected)
      @total_revenue = @selected.map {|k, v| v[0]}.reduce(0, :+)
      @total_cost = @selected.map {|k, v| v[1]}.reduce(0, :+)
      @total_minutes = @selected.map {|k, v| v[3]}.reduce(0, :+)
      @total_calls = @selected.map {|k, v| v[4]}.reduce(0, :+)
      #else
        #@selected = Rails.cache.read('customer_sel')
        #@total_revenue = @selected.map {|k, v| v[0]}.reduce(0, :+)
        #@total_cost = @selected.map {|k, v| v[1]}.reduce(0, :+)
        #@total_minutes = @selected.map {|k, v| v[3]}.reduce(0, :+)
        #@total_calls = @selected.map {|k, v| v[4]}.reduce(0, :+)
      #sort by params
      if params[:sort_by] == "name"
        @top_10_destinations_final =  @top_10_destinations_final.sort_by {|key, value| key}
      elsif params[:sort_by] == "revenue"
        @top_10_destinations_final =  @top_10_destinations_final.sort_by {|key, value| value[0]}.reverse
      elsif params[:sort_by] == "cost"
        @top_10_destinations_final =  @top_10_destinations_final.sort_by {|key, value| value[1]}.reverse
      elsif params[:sort_by] == "margin"
        @top_10_destinations_final =  @top_10_destinations_final.sort_by {|key, value| value[2]}.reverse
      elsif params[:sort_by] == "calls"
        @top_10_destinations_final =  @top_10_destinations_final.sort_by {|key, value| value[4]}.reverse
      else #minutes by default
        @top_10_destinations_final =  @top_10_destinations_final.sort_by {|key, value| value[3]}.reverse
      end

      /if !params['viewFrom'].eql?(nil) && !params['viewTo'].eql?(nil)
        @selected = Customer.all
        @total_revenue = @selected.map(&:revenue).sum
        @total_cost = @selected.map(&:cost).sum
        @total_minutes = @selected.map(&:minutes).sum
        @total_calls = @selected.map(&:num_calls).sum
      else
        @customers_hash, @selected = {}, {}
        #parse the input parameters and filter accordingly
        if params['viewFrom']
          @from_date = Time.new(params['viewFrom']['from(1i)'], params['viewFrom']['from(2i)'], params['viewFrom']['from(3i)'])
        else
          @from_date = Time.now
        end
        if params['viewTo']
          @to_date = Time.new(params['viewTo']['to(1i)'], params['viewTo']['to(2i)'], params['viewTo']['to(3i)'])
        else
          @to_date = Time.now
        end
        
        @selected = Customer.all
        @total_revenue = @selected.map(&:revenue).sum
        @total_cost = @selected.map(&:cost).sum
        @total_minutes = @selected.map(&:minutes).sum
        @total_calls = @selected.map(&:num_calls).sum
        #sort by params
        if params[:sort_by]
          @selected =  Customer.order(params[:sort_by] + " desc")
        end
      end/
    end
  end
  def customerInfo
    @top_10_destinations_final = {}
    @top_10_destinations = {}
    session[:customer_id] = params[:id] || session[:customer_id]
    @id = session[:customer_id]
    session[:customer_name] = params[:name] || session[:customer_name]
    @name = session[:customer_name]
    if params['viewFrom']
      @from_date = Time.new(params['viewFrom']['from(1i)'], params['viewFrom']['from(2i)'], params['viewFrom']['from(3i)'])
    else
      @from_date = Time.now
    end
    if params['viewTo']
      @to_date = Time.new(params['viewTo']['to(1i)'], params['viewTo']['to(2i)'], params['viewTo']['to(3i)'])
    else
      @to_date = Time.now
    end
    @from_date = getFromDate()
    @to_date = (Time.new(@from_date[0..3].to_i,@from_date[5..6].to_i,@from_date[8..9].to_i,@from_date[11..12].to_i,@from_date[14..15].to_i,@from_date[17..18].to_i) + 1.days - 1.seconds).to_s

    if not params[:sort_by]
      sql = "select count(A.CLD), A.CLD AS 'dst', A.connect_time AS 'calldate', A.i_account, D.i_customer, D.i_parent, D.name AS 'customer', B.i_vendor, sum(A.charged_quantity / 60) AS 'minutes', sum(A.charged_amount) as 'revenue', sum(B.charged_amount) AS 'cost', sum(A.charged_amount - B.charged_amount) as 'margin' from CDR_Vendors B join Customers D join CDR_Accounts A where (B.h323_conf_id = A.h323_conf_id) and (D.i_customer = A.i_customer) and (B.i_service = A.i_service) and A.connect_time between '#{@from_date}' and '#{@to_date}' and D.name like '#{session[:customer_name]}' group by A.CLD"
      rs = @@client.query(sql)
      rs.each do |row|
        if  @top_10_destinations.has_key?("#{row["dst"]}")
          @top_10_destinations["#{row["dst"]}"][0] += row["revenue"] rescue nil
          @top_10_destinations["#{row["dst"]}"][1] += row["cost"] rescue nil
          @top_10_destinations["#{row["dst"]}"][2] += row["margin"] rescue nil
          @top_10_destinations["#{row["dst"]}"][3] += row["minutes"] rescue nil
          @top_10_destinations["#{row["dst"]}"][4] += row["count(A.CLD)"]
        else
          @top_10_destinations["#{row["dst"]}"] = [row["revenue"], row["cost"] , row["margin"], row["minutes"], row["count(A.CLD)"]]
        end
      end
      @top_10_destinations.each do |dest, value|
        sql_next = "Select A.description, A.name, B.CLD from (v_Destinations A join CDR_Accounts B on A.i_dest = B.i_dest) where B.bill_time between '#{@from_date}' and '#{@to_date}' and B.CLD like '#{dest}' GROUP BY B.CLD;"
        rs_next = @@client.query(sql_next)
        rs_next.each do |row|
          if  @top_10_destinations_final.has_key?("#{row["name"]} - #{row["description"]}")
            @top_10_destinations_final["#{row["name"]} - #{row["description"]}"][0] += value[0] rescue nil
            @top_10_destinations_final["#{row["name"]} - #{row["description"]}"][1] += value[1] rescue nil
            @top_10_destinations_final["#{row["name"]} - #{row["description"]}"][2] += value[2] rescue nil
            @top_10_destinations_final["#{row["name"]} - #{row["description"]}"][3] += value[3] rescue nil
            @top_10_destinations_final["#{row["name"]} - #{row["description"]}"][4] = value[4]
          else
            @top_10_destinations_final["#{row["name"]} - #{row["description"]}"] = [value[0], value[1], value[2], value[3], value[4]]
          end
        end
      end
      Rails.cache.write('customer_info', @top_10_destinations_final)
      @total_revenue = @top_10_destinations_final.map {|k, v| v[0]}.reduce(0, :+)
      @total_cost = @top_10_destinations_final.map {|k, v| v[1]}.reduce(0, :+)
      @total_minutes = @top_10_destinations_final.map {|k, v| v[3]}.reduce(0, :+)
      @total_calls = @top_10_destinations_final.map {|k, v| v[4]}.reduce(0, :+)
    else
      @top_10_destinations_final = Rails.cache.read('customer_info')
      @total_revenue = @top_10_destinations_final.map {|k, v| v[0]}.reduce(0, :+)
      @total_cost = @top_10_destinations_final.map {|k, v| v[1]}.reduce(0, :+)
      @total_minutes = @top_10_destinations_final.map {|k, v| v[3]}.reduce(0, :+)
      @total_calls = @top_10_destinations_final.map {|k, v| v[4]}.reduce(0, :+)
    end

    #sort by params
    if params[:sort_by] == "name"
      @top_10_destinations_final =  @top_10_destinations_final.sort_by {|key, value| key}
    elsif params[:sort_by] == "revenue"
      @top_10_destinations_final =  @top_10_destinations_final.sort_by {|key, value| value[0]}.reverse
    elsif params[:sort_by] == "cost"
      @top_10_destinations_final =  @top_10_destinations_final.sort_by {|key, value| value[1]}.reverse
    elsif params[:sort_by] == "margin"
      @top_10_destinations_final =  @top_10_destinations_final.sort_by {|key, value| value[2]}.reverse
    elsif params[:sort_by] == "calls"
      @top_10_destinations_final =  @top_10_destinations_final.sort_by {|key, value| value[4]}.reverse
    else #minutes by default
      @top_10_destinations_final =  @top_10_destinations_final.sort_by {|key, value| value[3]}.reverse
    end
  end

  def topResellers
    @resellers_hash = {}
    @selected = {}
    @reseller_curr = [] #unique currencies that are available
    @total_revenue, @total_cost, @total_minutes, @total_calls = 0,0,0,0
    c=Savon.client(wsdl: "http://www.webservicex.net/CurrencyConvertor.asmx?WSDL")

    sql = "select distinct(iso_4217) from Customers where i_parent is NULL;"
    rs = @@client.query(sql)
    rs.each do |row|
      @reseller_curr.push(row["iso_4217"])
    end
    @reseller_curr.push("Show all (USD)")

    #parse the input parameters and filter accordingly
    if params['viewFrom']
      @from_date = Time.new(params['viewFrom']['from(1i)'], params['viewFrom']['from(2i)'], params['viewFrom']['from(3i)'])
    else
      @from_date = Time.now - 1.days
    end
    if params['viewTo']
      @to_date = Time.new(params['viewTo']['to(1i)'], params['viewTo']['to(2i)'], params['viewTo']['to(3i)'])
    else
      @to_date = Time.now
    end
    @from_date = getFromDate()
    @to_date = (Time.new(@from_date[0..3].to_i,@from_date[5..6].to_i,@from_date[8..9].to_i,@from_date[11..12].to_i,@from_date[14..15].to_i,@from_date[17..18].to_i) + 1.days - 1.seconds).to_s
    
    #to keep track of currency, default is USD
    if params[:curr]
      @currency = params[:curr]
    else
      @currency = 'Show all (USD)'
    end
    if not params[:sort_by]
      sql = "Select count(A.CLD), A.connect_time, D.i_customer, D.name AS customer, B.i_vendor, C.name AS 'vendor', sum(A.charged_quantity / 60) AS 'minutes', sum(A.charged_amount) AS 'revenue', sum(B.charged_amount) AS 'cost', sum(A.charged_amount - B.charged_amount) AS 'margin' from (((Vendors C join CDR_Vendors B) join Customers D) join CDR_Customers A) where ((C.i_vendor = B.i_vendor) and (B.h323_conf_id = A.h323_conf_id) and (D.i_customer = A.i_customer) and (B.i_service = B.i_service)) and A.connect_time between '#{@from_date}' and '#{@to_date}' and D.name not like 'zzz%' and i_parent is NULL group by D.name;"
      rs = @@client.query(sql)
      rs.each do |row|
        @resellers_hash["#{row["i_customer"]}"] = [row["revenue"], row["cost"] , row["margin"], row["minutes"], row["count(A.CLD)"], row["i_customer"], row["customer"]]
      end
      
      @resellers_hash.each do |k, v|
        sql_asr = "SELECT asr24hr FROM v_CDR_Customers_ASR WHERE i_customer like '#{v[5]}'" #for calculating asr
        rs_asr = @@client.query(sql_asr)

        if @currency.eql?("Show all (USD)")
          #if customer currency is same as reseller currency proceed, otherwise find that customer currency and convert everything
            sql_next = "SELECT * FROM Customers WHERE i_parent like '#{v[5]}' group by i_parent"
            rs_next = @@client.query(sql_next)
            rs_next.each do |cus|
              if cus["iso_4217"] != "USD"
                rate = convertToUSD(cus["iso_4217"])
              else
                rate = 1
              end
              if  @selected.has_key?("#{v[6]}")
                @selected["#{v[6]}"][0] += v[0]*rate.to_f rescue nil
                @selected["#{v[6]}"][1] += v[1]*rate.to_f rescue nil
                @selected["#{v[6]}"][2] += v[2]*rate.to_f rescue nil
                @selected["#{v[6]}"][3] += v[3]
                @selected["#{v[6]}"][4] += v[4]
              else
                @selected["#{v[6]}"] = [v[0]*rate.to_f, v[1]*rate.to_f, v[2]*rate.to_f, v[3], v[4], rs_asr.first["asr24hr"], v[5]]
              end
            end
        else
          @reseller_curr.each do |curr|
            if @currency.eql?(curr) and not @currency.eql?("Show all (USD)")
              sql = "SELECT * FROM Customers WHERE i_customer like '#{v[5]}' and iso_4217 like '#{curr}'"
              rs = @@client.query(sql)
              rs.each do |par|
                sql_next = "SELECT * FROM Customers WHERE i_parent like '#{par["i_customer"]}' group by i_parent"
                rs_next = @@client.query(sql_next)
                rs_next.each do |cus|
                  if  @selected.has_key?("#{par["name"]}")
                    @selected["#{par["name"]}"][0] += v[0] rescue nil
                    @selected["#{par["name"]}"][1] += v[1] rescue nil
                    @selected["#{par["name"]}"][2] += v[2] rescue nil
                    @selected["#{par["name"]}"][3] += v[3]
                    @selected["#{par["name"]}"][4] += v[4]
                  else
                    @selected["#{par["name"]}"] = [v[0], v[1], v[2], v[3], v[4], rs_asr.first["asr24hr"], v[5]]
                  end
                end
              end
            end
          end   
        end
      end
      Rails.cache.write('reseller_sel', @selected)
      @total_revenue = @selected.map {|k, v| v[0]}.reduce(0, :+)
      @total_cost = @selected.map {|k, v| v[1]}.reduce(0, :+)
      @total_minutes = @selected.map {|k, v| v[3]}.reduce(0, :+)
      @total_calls = @selected.map {|k, v| v[4]}.reduce(0, :+)
    else
      @selected = Rails.cache.read('reseller_sel')
      @total_revenue = @selected.map {|k, v| v[0]}.reduce(0, :+)
      @total_cost = @selected.map {|k, v| v[1]}.reduce(0, :+)
      @total_minutes = @selected.map {|k, v| v[3]}.reduce(0, :+)
      @total_calls = @selected.map {|k, v| v[4]}.reduce(0, :+)
    end

    #sort by params
    if params[:sort_by] == "name"
      @selected =  @selected.sort_by {|key, value| key}
    elsif params[:sort_by] == "revenue"
      @selected =  @selected.sort_by {|key, value| value[0]}.reverse
    elsif params[:sort_by] == "cost"
      @selected =  @selected.sort_by {|key, value| value[1]}.reverse
    elsif params[:sort_by] == "margin"
      @selected =  @selected.sort_by {|key, value| value[2]}.reverse
    else
      @selected =  @selected.sort_by {|key, value| value[3]}.reverse
    end
  end

  def resellerInfo
    @top_10_destinations_final = {}
    @top_10_destinations = {}
    session[:customer_id] = params[:id] || session[:customer_id]
    @id = session[:customer_id]
    session[:customer_name] = params[:name] || session[:customer_name]
    @name = session[:customer_name]
    if params['viewFrom']
      @from_date = Time.new(params['viewFrom']['from(1i)'], params['viewFrom']['from(2i)'], params['viewFrom']['from(3i)'])
    else
      @from_date = Time.now
    end
    if params['viewTo']
      @to_date = Time.new(params['viewTo']['to(1i)'], params['viewTo']['to(2i)'], params['viewTo']['to(3i)'])
    else
      @to_date = Time.now
    end
    @from_date = getFromDate()
    @to_date = (Time.new(@from_date[0..3].to_i,@from_date[5..6].to_i,@from_date[8..9].to_i,@from_date[11..12].to_i,@from_date[14..15].to_i,@from_date[17..18].to_i) + 1.days - 1.seconds).to_s

    if not params[:sort_by]
      sql = "select count(A.CLD), A.CLD AS 'dst', A.connect_time AS 'calldate', D.i_customer, D.i_parent, D.name AS 'customer', B.i_vendor, sum(A.charged_quantity / 60) AS 'minutes', sum(A.charged_amount) as 'revenue', sum(B.charged_amount) AS 'cost', sum(A.charged_amount - B.charged_amount) as 'margin' from CDR_Vendors B join Customers D join CDR_Customers A where (B.h323_conf_id = A.h323_conf_id) and (D.i_customer = A.i_customer) and (B.i_service = A.i_service) and A.connect_time between '#{@from_date}' and '#{@to_date}' and D.i_customer like '#{session[:customer_id]}' group by A.CLD;"
      rs = @@client.query(sql)
      rs.each do |row|
        if  @top_10_destinations.has_key?("#{row["dst"]}")
          @top_10_destinations["#{row["dst"]}"][0] += row["revenue"] rescue nil
          @top_10_destinations["#{row["dst"]}"][1] += row["cost"] rescue nil
          @top_10_destinations["#{row["dst"]}"][2] += row["margin"] rescue nil
          @top_10_destinations["#{row["dst"]}"][3] += row["minutes"] rescue nil
          @top_10_destinations["#{row["dst"]}"][4] += row["count(A.CLD)"]
        else
          @top_10_destinations["#{row["dst"]}"] = [row["revenue"], row["cost"] , row["margin"], row["minutes"], row["count(A.CLD)"]]
        end
      end
      @top_10_destinations.each do |dest, value|
        sql_next = "Select A.description, A.name, B.CLD from (v_Destinations A join CDR_Customers B on A.i_dest = B.i_dest) where B.bill_time between '#{@from_date}' and '#{@to_date}' and B.CLD like '#{dest}' GROUP BY B.CLD;"
        rs_next = @@client.query(sql_next)
        rs_next.each do |row|
          if  @top_10_destinations_final.has_key?("#{row["name"]} - #{row["description"]}")
            @top_10_destinations_final["#{row["name"]} - #{row["description"]}"][0] += value[0] rescue nil
            @top_10_destinations_final["#{row["name"]} - #{row["description"]}"][1] += value[1] rescue nil
            @top_10_destinations_final["#{row["name"]} - #{row["description"]}"][2] += value[2] rescue nil
            @top_10_destinations_final["#{row["name"]} - #{row["description"]}"][3] += value[3] rescue nil
            @top_10_destinations_final["#{row["name"]} - #{row["description"]}"][4] = value[4]
          else
            @top_10_destinations_final["#{row["name"]} - #{row["description"]}"] = [value[0], value[1], value[2], value[3], value[4]]
          end
        end
      end
      Rails.cache.write('reseller_info', @top_10_destinations_final)
      @total_revenue = @top_10_destinations_final.map {|k, v| v[0]}.reduce(0, :+)
      @total_cost = @top_10_destinations_final.map {|k, v| v[1]}.reduce(0, :+)
      @total_minutes = @top_10_destinations_final.map {|k, v| v[3]}.reduce(0, :+)
      @total_calls = @top_10_destinations_final.map {|k, v| v[4]}.reduce(0, :+)
    else
      @top_10_destinations_final = Rails.cache.read('reseller_info')
      @total_revenue = @top_10_destinations_final.map {|k, v| v[0]}.reduce(0, :+)
      @total_cost = @top_10_destinations_final.map {|k, v| v[1]}.reduce(0, :+)
      @total_minutes = @top_10_destinations_final.map {|k, v| v[3]}.reduce(0, :+)
      @total_calls = @top_10_destinations_final.map {|k, v| v[4]}.reduce(0, :+)
    end

    #sort by params
    if params[:sort_by] == "name"
      @top_10_destinations_final =  @top_10_destinations_final.sort_by {|key, value| key}
    elsif params[:sort_by] == "revenue"
      @top_10_destinations_final =  @top_10_destinations_final.sort_by {|key, value| value[0]}.reverse
    elsif params[:sort_by] == "cost"
      @top_10_destinations_final =  @top_10_destinations_final.sort_by {|key, value| value[1]}.reverse
    elsif params[:sort_by] == "margin"
      @top_10_destinations_final =  @top_10_destinations_final.sort_by {|key, value| value[2]}.reverse
    elsif params[:sort_by] == "calls"
      @top_10_destinations_final =  @top_10_destinations_final.sort_by {|key, value| value[4]}.reverse
    else #minutes by default
      @top_10_destinations_final =  @top_10_destinations_final.sort_by {|key, value| value[3]}.reverse
    end
  end

  def topCarriers
    @carriers_hash = {}
    @selected = {}
    @total_revenue, @total_cost, @total_minutes, @total_calls = 0,0,0,0

    if params['viewFrom']
      @from_date = Time.new(params['viewFrom']['from(1i)'], params['viewFrom']['from(2i)'], params['viewFrom']['from(3i)'])
    else
      @from_date = Time.now
    end
    if params['viewTo']
      @to_date = Time.new(params['viewTo']['to(1i)'], params['viewTo']['to(2i)'], params['viewTo']['to(3i)'])
    else
      @to_date = Time.now + 1.days
    end
    @from_date = getFromDate()
    @to_date = (Time.new(@from_date[0..3].to_i,@from_date[5..6].to_i,@from_date[8..9].to_i,@from_date[11..12].to_i,@from_date[14..15].to_i,@from_date[17..18].to_i) + 1.days - 1.seconds).to_s


    rate = convertToUSD("BRL")
    
    @selected = Carrier.all
    @total_revenue = @selected.map(&:revenue).sum
    @total_cost = @selected.map(&:cost).sum
    @total_minutes = @selected.map(&:minutes).sum
    @total_calls = @selected.map(&:num_calls).sum
    #sort by params
    if params[:sort_by]
      @selected =  Carrier.order(params[:sort_by] + " desc")
    end
  end

  def carrierInfo
    @top_10_destinations_final = {}
    @top_10_destinations = {}
    session[:carrier_id] = params[:id]
    @id = session[:carrier_id]
    session[:carrier_name] = params[:name] || session[:carrier_name]
    @name = session[:carrier_name]
    if params['viewFrom']
      @from_date = Time.new(params['viewFrom']['from(1i)'], params['viewFrom']['from(2i)'], params['viewFrom']['from(3i)'])
    else
      @from_date = Time.now
    end
    if params['viewTo']
      @to_date = Time.new(params['viewTo']['to(1i)'], params['viewTo']['to(2i)'], params['viewTo']['to(3i)'])
    else
      @to_date = Time.now
    end
    @from_date = getFromDate()
    @to_date = (Time.new(@from_date[0..3].to_i,@from_date[5..6].to_i,@from_date[8..9].to_i,@from_date[11..12].to_i,@from_date[14..15].to_i,@from_date[17..18].to_i) + 1.days - 1.seconds).to_s

    if not params[:sort_by]
      sql_res = "Select count(A.CLD), A.CLD AS 'dst', A.connect_time, B.i_vendor, C.name AS 'vendor', sum(B.charged_time / 60) AS 'minutes', sum(A.charged_amount) AS 'revenue', sum(B.charged_amount) AS 'cost', sum(A.charged_amount - B.charged_amount) AS 'margin' from ((Vendors C join CDR_Vendors B) join CDR_Customers A) where ((C.i_vendor = B.i_vendor) and (B.h323_conf_id = A.h323_conf_id) and (B.i_service = A.i_service)) and A.connect_time between '#{@from_date}' and '#{@to_date}' and A.charged_amount > 0 and C.name like '#{session[:carrier_name]}' group by A.CLD;"
      rs_res = @@client.query(sql_res)
      sql_cus = "Select count(A.CLD), A.CLD AS 'dst', A.connect_time, B.i_vendor, C.name AS 'vendor', D.i_customer, D.i_parent, sum(B.charged_time / 60) AS 'minutes', sum(A.charged_amount) AS 'revenue', sum(B.charged_amount) AS 'cost', sum(A.charged_amount - B.charged_amount) AS 'margin' from ((Vendors C join CDR_Vendors B join Customers D) join CDR_Accounts A) where ((C.i_vendor = B.i_vendor) and D.i_customer = A.i_customer and (B.h323_conf_id = A.h323_conf_id) and (B.i_service = A.i_service)) and A.connect_time between '#{@from_date}' and '#{@to_date}' and A.charged_amount > 0 and C.name like '#{session[:carrier_name]}' group by A.CLD;"
      rs_cus = @@client.query(sql_cus)
      rs_res.each do |row|
        if  @top_10_destinations.has_key?("#{row["dst"]}")
          @top_10_destinations["#{row["dst"]}"][0] += row["revenue"] rescue nil
          @top_10_destinations["#{row["dst"]}"][1] += row["cost"] rescue nil
          @top_10_destinations["#{row["dst"]}"][2] += row["margin"] rescue nil
          @top_10_destinations["#{row["dst"]}"][3] += row["minutes"] rescue nil
          @top_10_destinations["#{row["dst"]}"][4] += row["count(A.CLD)"]
        else
          @top_10_destinations["#{row["dst"]}"] = [row["revenue"], row["cost"] , row["margin"], row["minutes"], row["count(A.CLD)"]]
        end
      end
      rs_cus.each do |row|
        if  @top_10_destinations.has_key?("#{row["dst"]}")
          @top_10_destinations["#{row["dst"]}"][0] += row["revenue"] rescue nil
          @top_10_destinations["#{row["dst"]}"][1] += row["cost"] rescue nil
          @top_10_destinations["#{row["dst"]}"][2] += row["margin"] rescue nil
          @top_10_destinations["#{row["dst"]}"][3] += row["minutes"] rescue nil
          @top_10_destinations["#{row["dst"]}"][4] += row["count(A.CLD)"]
        else
          @top_10_destinations["#{row["dst"]}"] = [row["revenue"], row["cost"] , row["margin"], row["minutes"], row["count(A.CLD)"]]
        end
      end
      @top_10_destinations.each do |dest, value|
        sql_next = "Select A.description, A.name, B.CLD from (v_Destinations A join CDR_Vendors B on A.i_dest = B.i_dest) where B.bill_time between '#{@from_date}' and '#{@to_date}' and B.CLD like '#{dest}' GROUP BY A.name;"
        rs_next = @@client.query(sql_next)
        rs_next.each do |row|
          if  @top_10_destinations_final.has_key?("#{row["name"]} - #{row["description"]}")
            @top_10_destinations_final["#{row["name"]} - #{row["description"]}"][0] += value[0] rescue nil
            @top_10_destinations_final["#{row["name"]} - #{row["description"]}"][1] += value[1] rescue nil
            @top_10_destinations_final["#{row["name"]} - #{row["description"]}"][2] += value[2] rescue nil
            @top_10_destinations_final["#{row["name"]} - #{row["description"]}"][3] += (value[3].to_f)/60 rescue nil
            @top_10_destinations_final["#{row["name"]} - #{row["description"]}"][4] = value[4]
          else
            @top_10_destinations_final["#{row["name"]} - #{row["description"]}"] = [value[0], value[1], value[2], (value[3].to_f)/60, value[4]]
          end
        end
      end
      Rails.cache.write('carrier_info', @top_10_destinations_final)
      @total_revenue = @top_10_destinations_final.map {|k, v| v[0]}.reduce(0, :+)
      @total_cost = @top_10_destinations_final.map {|k, v| v[1]}.reduce(0, :+)
      @total_minutes = @top_10_destinations_final.map {|k, v| v[3]}.reduce(0, :+)
      @total_calls = @top_10_destinations_final.map {|k, v| v[4]}.reduce(0, :+)
    else
      @top_10_destinations_final = Rails.cache.read('carrier_info')
      @total_revenue = @top_10_destinations_final.map {|k, v| v[0]}.reduce(0, :+)
      @total_cost = @top_10_destinations_final.map {|k, v| v[1]}.reduce(0, :+)
      @total_minutes = @top_10_destinations_final.map {|k, v| v[3]}.reduce(0, :+)
      @total_calls = @top_10_destinations_final.map {|k, v| v[4]}.reduce(0, :+)
    end

    #sort by params
    if params[:sort_by] == "name"
      @top_10_destinations_final =  @top_10_destinations_final.sort_by {|key, value| key}
    elsif params[:sort_by] == "revenue"
      @top_10_destinations_final =  @top_10_destinations_final.sort_by {|key, value| value[0]}.reverse
    elsif params[:sort_by] == "cost"
      @top_10_destinations_final =  @top_10_destinations_final.sort_by {|key, value| value[1]}.reverse
    elsif params[:sort_by] == "minutes"
      @top_10_destinations_final =  @top_10_destinations_final.sort_by {|key, value| value[3]}.reverse
    elsif params[:sort_by] == "calls"
      @top_10_destinations_final =  @top_10_destinations_final.sort_by {|key, value| value[4]}.reverse
    else #minutes by default
      @top_10_destinations_final =  @top_10_destinations_final.sort_by {|key, value| value[2]}.reverse
    end
  end

  private
  def convertToUSD(from)
    c=Savon.client(wsdl: "http://www.webservicex.net/CurrencyConvertor.asmx?WSDL")
    r=c.call(:conversion_rate, message: {'FromCurrency' => from, 'ToCurrency' => "USD"})
    return r.to_hash[:conversion_rate_response][:conversion_rate_result]
  end
end

#to get the customer currency and convert that to the parent's currency
#select iso_4217 from Customers where i_parent like '2109'
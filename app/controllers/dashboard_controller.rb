require 'savon'
require "mysql2"
DB_HOST = "208.65.111.153"
DB_USER = "reports"
DB_PASSWORD = "u2ns8uj28yshu"
DB = "porta-billing"
@@client = Mysql2::Client.new(:host => DB_HOST, :username => DB_USER, :password=> DB_PASSWORD, :database => DB)  
class DashboardController < ApplicationController
  before_filter :require_login
  def index
    @from_date = (Time.now).strftime("%Y-%m-%d") + ' 00:00:00'
    @to_date = (Time.now).strftime("%Y-%m-%d") + ' 23:59:59'
    @customers_hash = {}
    @selected_customers = {}
    c=Savon.client(wsdl: "http://www.webservicex.net/CurrencyConvertor.asmx?WSDL")

    if not params[:sort_by]
      sql = "SELECT customer, i_customer, sum(revenue), sum(cost), sum(margin), sum(minutes), count(CLD) FROM v_CDR_Accounts WHERE calldate between '#{@from_date}' and '#{@to_date}' and i_parent is NULL group by customer"
      rs = @@client.query(sql)
      rs.each do |row|
        if @customers_hash.has_key?("#{row["customer"]}")
          @customers_hash["#{row["customer"]}"][0] += row["sum(revenue)"] rescue nil
          @customers_hash["#{row["customer"]}"][1] += row["sum(cost)"] rescue nil
          @customers_hash["#{row["customer"]}"][2] += row["sum(margin)"] rescue nil
          @customers_hash["#{row["customer"]}"][3] += row["sum(minutes)"] rescue nil
          @customers_hash["#{row["customer"]}"][4] += row["count(CLD)"]
          @customers_hash["#{row["customer"]}"][5] = row["i_customer"]
        else
          @customers_hash["#{row["customer"]}"] = [row["sum(revenue)"], row["sum(cost)"] , row["sum(margin)"], row["sum(minutes)"], row["count(CLD)"], row["i_customer"]]
        end
      end

      @customers_hash.each do |k, v|
        sql = "SELECT name, iso_4217 FROM Customers WHERE i_customer like '#{v[5]}'"
        rs = @@client.query(sql)
        name, iso_4217 = rs.first["name"], rs.first["iso_4217"]
        if iso_4217 != 'USD'
          rate_customers = convertToUSD(iso_4217)
          @selected_customers["#{name}"][0] += v[0]*rate_customers.to_f rescue nil
          @selected_customers["#{name}"][1] += v[1]*rate_customers.to_f rescue nil
          @selected_customers["#{name}"][2] += v[2]*rate_customers.to_f rescue nil
          @selected_customers["#{name}"][3] += v[3] rescue nil
          @selected_customers["#{name}"][4] += v[4]
          @selected_customers["#{name}"][5] += v[5]
        else
          @selected_customers = @customers_hash.clone
        end
      end
    else
      @selected_customers = Rails.cache.read('customer_sel')
    end
    #sort by params
    if params[:sort_by] == "name"
      @selected_customers =  @selected_customers.sort_by {|key, value| key}
    elsif params[:sort_by] == "revenue"
      @selected_customers =  @selected_customers.sort_by {|key, value| value[0]}.reverse
    elsif params[:sort_by] == "cost"
      @selected_customers =  @selected_customers.sort_by {|key, value| value[1]}.reverse
    elsif params[:sort_by] == "margin"
      @selected_customers =  @selected_customers.sort_by {|key, value| value[2]}.reverse
    else
      @selected_customers =  @selected_customers.sort_by {|key, value| value[3]}.reverse
    end

    @carriers_hash = {}
    @selected_vendors = {}
    rate_vendors = 1

    if not params[:sort_by]
      sql = "SELECT vendor, count(CLD), sum(revenue), sum(cost), sum(margin), sum(seconds), i_vendor FROM v_CDR_Vendors WHERE calldate between '#{@from_date}' and '#{@to_date}' and customer not like 'zzz%' and revenue > 0 group by vendor"
      rs = @@client.query(sql)
      rs.each do |row|
        if  @carriers_hash.has_key?("#{row["vendor"]}")
          @carriers_hash["#{row["vendor"]}"][0] += row["sum(revenue)"] rescue nil
          @carriers_hash["#{row["vendor"]}"][1] += row["sum(cost)"] rescue nil
          @carriers_hash["#{row["vendor"]}"][2] += row["sum(margin)"] rescue nil
          @carriers_hash["#{row["vendor"]}"][3] += row["sum(seconds)"]/60 rescue nil
          @carriers_hash["#{row["vendor"]}"][4] += row["count(CLD)"]
          @carriers_hash["#{row["vendor"]}"][5] =  row["i_vendor"]
        else
          @carriers_hash["#{row["vendor"]}"] = [row["sum(revenue)"] || 0, row["sum(cost)"] , row["sum(margin)"] || 0, row["sum(seconds)"]/60, row["count(CLD)"], row["i_vendor"]]
        end
      end
      @carriers_hash.each do |k, v|
        sql = "SELECT * FROM Vendors WHERE i_vendor like '#{v[5]}'"
        rs = @@client.query(sql)
        rs.each do |row|
          if row["iso_4217"] != 'USD'
            rate_vendors= convertToUSD(row["iso_4217"])
          end
          if  @selected_vendors.has_key?("#{row["name"]}")
            @selected_vendors["#{row["name"]}"][0] += v[0]*rate_vendors.to_f rescue nil
            @selected_vendors["#{row["name"]}"][1] += v[1]*rate_vendors.to_f rescue nil
            @selected_vendors["#{row["name"]}"][2] += v[2]*rate_vendors.to_f rescue nil
            @selected_vendors["#{row["name"]}"][3] += v[3] rescue nil
            @selected_vendors["#{row["name"]}"][4] += v[4]
            @selected_vendors["#{row["name"]}"][5] += v[5]
          else
            @selected_vendors["#{row["name"]}"] = [v[0]*rate_vendors.to_f, v[1]*rate_vendors.to_f, v[2]*rate_vendors.to_f, v[3], v[4], v[5]]
          end
        end
      end
      Rails.cache.write('carrier_sel', @selected_vendors)
    else
      @selected_vendors = Rails.cache.read('carrier_sel', @selected_vendors)
    end
    #sort by params
    if params[:sort_by] == "name"
      @selected_vendors =  @selected_vendors.sort_by {|key, value| key}
    elsif params[:sort_by] == "revenue"
      @selected_vendors =  @selected_vendors.sort_by {|key, value| value[0]}.reverse
    elsif params[:sort_by] == "cost"
      @selected_vendors =  @selected_vendors.sort_by {|key, value| value[1]}.reverse
    elsif params[:sort_by] == "margin"
      @selected_vendors =  @selected_vendors.sort_by {|key, value| value[2]}.reverse
    else
      @selected_vendors =  @selected_vendors.sort_by {|key, value| value[3]}.reverse
    end

    #also show the accumulated traffic for last week
    @week_traffic_refined = {}
    sql = "SELECT customer, calldate, count(CLD), sum(revenue), sum(cost), sum(margin), sum(minutes) FROM v_CDR_Accounts WHERE revenue > 0 and calldate between '#{Time.now-6.days}' and '#{Time.now}' group by calldate"
    rs = @@client.query(sql)
    rs.each do |row|
      day = row["calldate"].strftime('%Y-%m-%d')
      if @week_traffic_refined.has_key?("#{day}")
        @week_traffic_refined["#{day}"][0] += row["sum(revenue)"] rescue nil
        @week_traffic_refined["#{day}"][1] += row["sum(cost)"] rescue nil
        @week_traffic_refined["#{day}"][2] += row["sum(margin)"] rescue nil
        @week_traffic_refined["#{day}"][3] += row["sum(minutes)"] rescue nil
        @week_traffic_refined["#{day}"][4] += row["count(CLD)"]
      else
        @week_traffic_refined["#{day}"] = [row["sum(revenue)"], row["sum(cost)"] , row["sum(margin)"], row["sum(minutes)"], row["count(CLD)"]]
      end
    end
    @week_traffic_refined.sort_by {|key, value| key}
  end

  def topCustomers
    @customers_hash = {}
    @selected = {}
    @temp = {}
    @customer_curr = []
    sql = "select distinct(iso_4217) from Customers;"
    rs = @@client.query(sql)
    rs.each do |row|
      @customer_curr.push(row["iso_4217"])
    end
    @customer_curr.push("Show all (USD)")

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
    @from_date = @from_date.strftime("%Y-%m-%d") + ' 00:00:00'
    @to_date = @to_date.strftime("%Y-%m-%d") + ' 23:59:59'
    
    #to keep track of currency, default is USD
    if params[:curr]
      @currency = params[:curr]
    else
      @currency = 'Show all (USD)'
    end

    if not params[:sort_by]
      sql = "SELECT customer, i_customer, sum(revenue), sum(cost), sum(margin), sum(minutes), count(CLD) FROM v_CDR_Accounts WHERE calldate between '#{@from_date}' and '#{@to_date}' and i_parent is NULL group by customer"
      rs = @@client.query(sql)
      rs.each do |row|
        if @customers_hash.has_key?("#{row["customer"]}")
          @customers_hash["#{row["customer"]}"][0] += row["sum(revenue)"] rescue nil
          @customers_hash["#{row["customer"]}"][1] += row["sum(cost)"] rescue nil
          @customers_hash["#{row["customer"]}"][2] += row["sum(margin)"] rescue nil
          @customers_hash["#{row["customer"]}"][3] += row["sum(minutes)"] rescue nil
          @customers_hash["#{row["customer"]}"][4] += row["count(CLD)"]
          @customers_hash["#{row["customer"]}"][5] = row["i_customer"]
        else
          @customers_hash["#{row["customer"]}"] = [row["sum(revenue)"], row["sum(cost)"] , row["sum(margin)"], row["sum(minutes)"], row["count(CLD)"], row["i_customer"]]
        end
      end

      @customers_hash.each do |k, v|
        if @currency.eql?("Show all (USD)")
          sql = "SELECT * FROM Customers WHERE i_customer like '#{v[5]}'"
          rs = @@client.query(sql)
          rs.each do |row|
            if row["iso_4217"] != "USD"
              rate = convertToUSD(row["iso_4217"])
            else
              rate = 1
            end
            if  @selected.has_key?("#{row["name"]}")
              @selected["#{row["name"]}"][0] += (v[0]*rate.to_f) rescue nil
              @selected["#{row["name"]}"][1] += (v[1]*rate.to_f) rescue nil
              @selected["#{row["name"]}"][2] += (v[2]*rate.to_f) rescue nil
              @selected["#{row["name"]}"][3] += v[3] rescue nil
              @selected["#{row["name"]}"][4] += v[4]
              @selected["#{row["name"]}"][6] = v[5]
              @selected["#{row["name"]}"][7] = 0
            else
              @selected["#{row["name"]}"] = [v[0]*rate.to_f, v[1]*rate.to_f, v[2]*rate.to_f, v[3], v[4],  0, v[5], 0]
            end
            sql_asr = "SELECT asr24hr FROM v_CDR_Customers_ASR WHERE i_customer like '#{v[5]}'"
            rs_asr = @@client.query(sql_asr)
            @selected["#{row["name"]}"][7] = (rs_asr.first["asr24hr"]) rescue nil
          end
        else
          @customer_curr.each do |curr|
            if @currency.eql?(curr) and not @currency.eql?("Show all (USD)")
              sql = "SELECT * FROM Customers WHERE i_customer like '#{v[5]}' and iso_4217 like '#{curr}'"
              rs = @@client.query(sql)
              rs.each do |row|
                if  @selected.has_key?("#{row["name"]}")
                  @selected["#{row["name"]}"][0] += v[0] rescue nil
                  @selected["#{row["name"]}"][1] += v[1] rescue nil
                  @selected["#{row["name"]}"][2] += v[2] rescue nil
                  @selected["#{row["name"]}"][3] += v[3] rescue nil
                  @selected["#{row["name"]}"][4] += v[4]
                  @selected["#{row["name"]}"][6] = v[5]
                  @selected["#{row["name"]}"][7] = 0
                else
                  @selected["#{row["name"]}"] = [v[0], v[1] , v[2], v[3], v[4], 0, v[5], 0]
                end
                sql_asr = "SELECT asr24hr FROM v_CDR_Customers_ASR WHERE i_customer like '#{v[5]}'"
                rs_asr = @@client.query(sql_asr)
                @selected["#{row["name"]}"][7] = (rs_asr.first["asr24hr"]) rescue nil
              end
            end
          end
        end
      end
      Rails.cache.write('customer_sel', @selected)
    else
      @selected = Rails.cache.read('customer_sel')
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
    elsif params[:sort_by] == "calls"
      @selected =  @selected.sort_by {|key, value| value[4]}.reverse
    else
      @selected =  @selected.sort_by {|key, value| value[3]}.reverse

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
    @from_date = @from_date.strftime("%Y-%m-%d") + ' 00:00:00'
    @to_date = @to_date.strftime("%Y-%m-%d") + ' 23:59:59'

    if not params[:sort_by]
      sql = "select dst, count(dst), sum(revenue), sum(cost), sum(margin), sum(minutes), i_customer from v_CDR_Accounts where i_customer like '#{session[:customer_id]}' and calldate between '#{@from_date}' and '#{@to_date}' and revenue > 0 GROUP BY dst;"
      rs = @@client.query(sql)
      rs.each do |row|
        if  @top_10_destinations.has_key?("#{row["dst"]}")
          @top_10_destinations["#{row["dst"]}"][0] += row["sum(revenue)"] rescue nil
          @top_10_destinations["#{row["dst"]}"][1] += row["sum(cost)"] rescue nil
          @top_10_destinations["#{row["dst"]}"][2] += row["sum(margin)"] rescue nil
          @top_10_destinations["#{row["dst"]}"][3] += row["sum(minutes)"] rescue nil
          @top_10_destinations["#{row["dst"]}"][4] += row["count(dst)"]
        else
          @top_10_destinations["#{row["dst"]}"] = [row["sum(revenue)"], row["sum(cost)"] , row["sum(margin)"], row["sum(minutes)"], row["count(dst)"]]
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
      @from_date = Time.now
    end
    if params['viewTo']
      @to_date = Time.new(params['viewTo']['to(1i)'], params['viewTo']['to(2i)'], params['viewTo']['to(3i)'])
    else
      @to_date = Time.now
    end
    @from_date = @from_date.strftime("%Y-%m-%d") + ' 00:00:00'
    @to_date = @to_date.strftime("%Y-%m-%d") + ' 23:59:59'
    
    #to keep track of currency, default is USD
    if params[:curr]
      @currency = params[:curr]
    else
      @currency = 'Show all (USD)'
    end
    if not params[:sort_by]
      sql = "SELECT i_customer, sum(revenue), sum(cost), sum(margin), count(CLD) FROM v_CDR_Customers WHERE calldate between '#{@from_date}' and '#{@to_date}' and i_parent is NULL group by i_customer"
      rs = @@client.query(sql)
      rs.each do |row|
        if @resellers_hash.has_key?("#{row["i_customer"]}")
          @resellers_hash["#{row["i_customer"]}"][0] += row["sum(revenue)"] rescue nil
          @resellers_hash["#{row["i_customer"]}"][1] += row["sum(cost)"] rescue nil
          @resellers_hash["#{row["i_customer"]}"][2] += row["sum(margin)"] rescue nil
          @resellers_hash["#{row["i_customer"]}"][3] = 0.0 rescue nil
          @resellers_hash["#{row["i_customer"]}"][4] += row["count(CLD)"]
          @resellers_hash["#{row["i_customer"]}"][5] = row["i_customer"]#to track the customer currency
        else
          @resellers_hash["#{row["i_customer"]}"] = [row["sum(revenue)"], row["sum(cost)"] , row["sum(margin)"], 0.0, row["count(CLD)"], row["i_customer"]]
        end

      end
      
      @resellers_hash.each do |k, v|
        sql_asr = "SELECT asr24hr FROM v_CDR_Customers_ASR WHERE i_customer like '#{v[5]}'" #for calculating asr
        rs_asr = @@client.query(sql_asr)

        minutes_sql = "select sum(used_quantity) from CDR_Customers where i_customer like #{v[5]} and bill_time between '#{@from_date}' and '#{@to_date}'"
        rs_minutes = @@client.query(minutes_sql) #for calculating minutes

        if @currency.eql?("Show all (USD)")
          #if customer currency is same as reseller currency proceed, otherwise find that customer currency and convert everything
          sql = "SELECT * FROM Customers WHERE i_customer like '#{v[5]}'"
          rs = @@client.query(sql)
          rs.each do |par|
            sql_next = "SELECT * FROM Customers WHERE i_parent like '#{par["i_customer"]}' group by i_parent"
            rs_next = @@client.query(sql_next)
            rs_next.each do |cus|
              if cus["iso_4217"] != "USD"
                rate = convertToUSD(cus["iso_4217"])
              else
                rate = 1
              end
              if  @selected.has_key?("#{par["name"]}")
                @selected["#{par["name"]}"][0] += v[0]*rate.to_f rescue nil
                @selected["#{par["name"]}"][1] += v[1]*rate.to_f rescue nil
                @selected["#{par["name"]}"][2] += v[2]*rate.to_f rescue nil
                @selected["#{par["name"]}"][3] += (rs_minutes.first["sum(used_quantity)"]).to_f/60
                @selected["#{par["name"]}"][4] += v[4]
              else
                @selected["#{par["name"]}"] = [v[0]*rate.to_f, v[1]*rate.to_f, v[2]*rate.to_f, (rs_minutes.first["sum(used_quantity)"].to_f)/60, v[4], rs_asr.first["asr24hr"]]
              end
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
                    @selected["#{par["name"]}"][3] += (rs_minutes.first["sum(used_quantity)"]).to_f/60
                    @selected["#{par["name"]}"][4] += v[4]
                  else
                    @selected["#{par["name"]}"] = [v[0], v[1], v[2], (rs_minutes.first["sum(used_quantity)"]).to_f/60, v[4], rs_asr.first["asr24hr"]]
                  end
                end
              end
            end
          end   
        end
      end
      Rails.cache.write('reseller_sel', @selected)
    else
      @selected = Rails.cache.read('reseller_sel')
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

  def topCarriers
    @carriers_hash = {}
    @selected = {}
    @vendor_curr = []
    rate = 1
    c=Savon.client(wsdl: "http://www.webservicex.net/CurrencyConvertor.asmx?WSDL")
    sql = "select distinct(iso_4217) from Vendors;"
    rs = @@client.query(sql)
    rs.each do |row|
      @vendor_curr.push(row["iso_4217"])
    end
    @vendor_curr.push("Show all (USD)")

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
    @from_date = @from_date.strftime("%Y-%m-%d") + ' 00:00:00'
    @to_date = @to_date.strftime("%Y-%m-%d") + ' 23:59:59'

    if params[:curr]
      @currency = params[:curr]
    else
      @currency = 'Show all (USD)'
    end

    if not params[:sort_by]
      sql = "SELECT vendor, count(CLD), sum(revenue), sum(cost), sum(margin), sum(seconds), i_vendor FROM v_CDR_Vendors WHERE calldate between '#{@from_date}' and '#{@to_date}' and revenue > 0 and customer not like 'zzz%' group by vendor"
      rs = @@client.query(sql)
      rs.each do |row|
        if  @carriers_hash.has_key?("#{row["vendor"]}")
          @carriers_hash["#{row["vendor"]}"][0] += row["sum(revenue)"] rescue nil
          @carriers_hash["#{row["vendor"]}"][1] += row["sum(cost)"] rescue nil
          @carriers_hash["#{row["vendor"]}"][2] += row["sum(margin)"] rescue nil
          @carriers_hash["#{row["vendor"]}"][3] += row["sum(seconds)"]/60 rescue nil
          @carriers_hash["#{row["vendor"]}"][4] += row["count(CLD)"]
          @carriers_hash["#{row["vendor"]}"][5] =  row["i_vendor"]
        else
          @carriers_hash["#{row["vendor"]}"] = [row["sum(revenue)"] || 0, row["sum(cost)"] , row["sum(margin)"] || 0, row["sum(seconds)"]/60, row["count(CLD)"], row["i_vendor"]]
        end
      end
      @carriers_hash.each do |k, v|
        if @currency.eql?("Show all (USD)")
          #sql_asr = "SELECT sum(calls), sum(attempts) FROM ASR_Vendors WHERE i_vendor like '#{v[5]}' and day like '#{day}';" #for calculating asr
          #rs_asr = @@client.query(sql_asr)
          #if rs_asr.first["sum(calls)"].eql?(nil)
          #  rs_asr.first["sum(calls)"] = 0
          #  rs_asr.first["sum(attempts)"] = 1
          #end
          sql = "SELECT * FROM Vendors WHERE i_vendor like '#{v[5]}'"
          rs = @@client.query(sql)
          rs.each do |row|
            if row["iso_4217"] != "USD"
              rate = convertToUSD(row["iso_4217"])
            else
              rate = 1
            end
            if  @selected.has_key?("#{row["name"]}")
              @selected["#{row["name"]}"][0] += (v[0]*rate.to_f) rescue nil
              @selected["#{row["name"]}"][1] += (v[1]*rate.to_f) rescue nil
              @selected["#{row["name"]}"][2] += (v[2]*rate.to_f) rescue nil
              @selected["#{row["name"]}"][3] += v[3] rescue nil
              @selected["#{row["name"]}"][4] += v[4]
            else
              @selected["#{row["name"]}"] = [v[0]*rate.to_f, v[1]*rate.to_f, v[2]*rate.to_f, v[3], v[4], v[5]]
            end
          end
        else
          @vendor_curr.each do |curr|
            if @currency.eql?(curr) and not @currency.eql?("Show all (USD)")
              sql = "SELECT * FROM Vendors WHERE i_vendor like '#{v[5]}' and iso_4217 like '#{curr}'"
              rs = @@client.query(sql)
              rs.each do |row|
                if  @selected.has_key?("#{row["name"]}")
                  @selected["#{row["name"]}"][0] += v[0] rescue nil
                  @selected["#{row["name"]}"][1] += v[1] rescue nil
                  @selected["#{row["name"]}"][2] += v[2] rescue nil
                  @selected["#{row["name"]}"][3] += v[3] rescue nil
                  @selected["#{row["name"]}"][4] += v[4]
                else
                  @selected["#{row["name"]}"] = [v[0], v[1] , v[2], v[3], v[4], v[5]]
                end
              end
            end
          end
        end   
      end
      Rails.cache.write('carrier_sel', @selected)
    else
      @selected = Rails.cache.read('carrier_sel', @selected)
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
    @from_date = @from_date.strftime("%Y-%m-%d") + ' 00:00:00'
    @to_date = @to_date.strftime("%Y-%m-%d") + ' 23:59:59'

    if not params[:sort_by]
      sql = "select CLD, count(CLD), sum(revenue), sum(cost), sum(margin), sum(seconds), i_customer from v_CDR_Vendors where i_vendor like '#{session[:carrier_id]}' and calldate between '#{@from_date}' and '#{@to_date}' and revenue > 0 GROUP BY CLD;"
      rs = @@client.query(sql)
      rs.each do |row|
        if  @top_10_destinations.has_key?("#{row["CLD"]}")
          @top_10_destinations["#{row["CLD"]}"][0] += row["sum(revenue)"] rescue nil
          @top_10_destinations["#{row["CLD"]}"][1] += row["sum(cost)"] rescue nil
          @top_10_destinations["#{row["CLD"]}"][2] += row["sum(margin)"] rescue nil
          @top_10_destinations["#{row["CLD"]}"][3] += row["sum(seconds)"] rescue nil
          @top_10_destinations["#{row["CLD"]}"][4] += row["count(CLD)"]
        else
          @top_10_destinations["#{row["CLD"]}"] = [row["sum(revenue)"], row["sum(cost)"] , row["sum(margin)"], row["sum(seconds)"], row["count(CLD)"]]
        end
      end
      @top_10_destinations.each do |dest, value|
        sql_next = "Select A.description, A.name, B.CLD from (v_Destinations A join CDR_Vendors B on A.i_dest = B.i_dest) where B.bill_time between '#{@from_date}' and '#{@to_date}' and B.CLD like '#{dest}' GROUP BY B.CLD;"
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
require 'csv'

# LiveInternet statistic parse
# 
# Author:: Laushkin Dmitriy (mailto:mr.rufoos@gmail.com)

module Liveinternet
  class Liveinternet
    attr_accessor :base_uri, :cookie_manager, :passwords
    attr_reader :date_to

    BASE_URI = 'http://www.liveinternet.ru/stat/%s/?lang=en'
    DEMOGRAPHY_URI = "http://www.liveinternet.ru/stat/%s/demo.csv?id=25524519;id=25524495;id=25524529;id=25524473;id=25524485;id=25524451;id=25524507;id=25524439;id=25524463;id=25524541;date=%s;period=week;graph=csv&lang=en"
    COUNTRIES_URI = "http://www.liveinternet.ru/stat/%s/countries.csv?id=2;id=6;id=25;id=34;id=62;id=50;id=51;id=3;id=59;id=0;id=48;date=%s;period=week;graph=csv&lang=en"
    REGIONS_URI = "http://www.liveinternet.ru/stat/%s/regions.csv?id=1;id=2;id=3;id=4;id=5;id=6;id=8;id=9;id=10;id=12;id=14;id=16;id=19;id=19;id=27;id=34;id=50;graph=csv;period=week;date=%s&lang=en"
    VISITORS_URI = "http://www.liveinternet.ru/stat/%s/visitors.csv?id=7;date=%s;period=week;graph=csv&lang=en"

    def initialize
      @base_uri = 'http://www.liveinternet.ru/stat/%s/'
      @http = HTTPClient.new
      @http.agent_name = 'User-Agent: Mozilla/5.0 (X11; Linux i686; rv:2.0.1) Gecko/20100101 Firefox/4.0.1'
      @cookie_manager = WebAgent::CookieManager.new
      @http.cookie_manager = @cookie_manager
      @passwords = {}
    end

    def is_private?(url)
      client = @http.get(sprintf(BASE_URI, url))
      return client.status == 200 && !client.body['it is necessary to enter the password'].nil?
    end

    def check_open_url(url)
      result = base_read(url)
      return I18n.t('linternet.server_error') if result[0].status != 200
      return I18n.t('linternet.address_is_not_registerd') if result[0].body['such address is not registered']
      return I18n.t('linternet.password_required') if result[0].body['it is necessary to enter the password']
      return I18n.t('linternet.excluded_from_rating') if result[0].body['moderator has excluded the site from rating']
      return nil
    end

    def check_private_url(url, liveinternet_pass)
      result = base_read(url)
      if result[0].status == 200 && result[0].body['it is necessary to enter the password']
        doc = Nokogiri.parse result[0].body
        form_parameters = doc.xpath('//form').xpath('//input').reduce(Hash[]) {|memo, input|
          memo[input.attributes['name'].to_s] = input.attributes['value'].to_s
          memo
        }
        form_parameters['password'] = liveinternet_pass
        form_parameters['keep_password'] = "on"
        message = @http.post result[1], form_parameters
        
        return I18n.t('linternet.wrong_password') if message.status != 302
      else
        check_open_url(url)
      end
    end

    def demography(url, date = Date.today)
      # Устанавливаем куки relgraph, чтобы отдавал статистику в процентах
      # set_cookie('relgraph', 'yes', url)

      @date_to = date.is_a?(String) ? Date.parse(date) : date
      csv_url = sprintf(DEMOGRAPHY_URI, url, date_to.strftime('%Y-%m-%d'))
      parse_csv(csv_url)
    end

    def regions(url, date = Date.today)
      # Устанавливаем куки relgraph, чтобы отдавал статистику в процентах
      # set_cookie('relgraph', 'yes', url)

      @date_to = date.is_a?(String) ? Date.parse(date) : date
      csv_url = sprintf(REGIONS_URI, url, date_to.strftime('%Y-%m-%d'))
      parse_csv(csv_url)
    end

    def countries(url, date = Date.today)
      # Устанавливаем куки relgraph, чтобы отдавал статистику в процентах
      # set_cookie('relgraph', 'yes', url)

      @date_to = date.is_a?(String) ? Date.parse(date) : date
      csv_url = sprintf(COUNTRIES_URI, url, date_to.strftime('%Y-%m-%d'))
      parse_csv(csv_url)
    end

    def visitors(url, date = Date.today)
      @date_to = date.is_a?(String) ? Date.parse(date) : date
      csv_url = sprintf(VISITORS_URI, url, date_to.strftime('%Y-%m-%d'))
      parse_csv(csv_url)
    end

    def set_password(url, pass)
      @passwords.merge!({url => pass})
    end

    def auth(url)
      password = @passwords[url] || nil
      if password
        client = @http.post(sprintf(BASE_URI, url), {"url" => "http://#{url}", "password" => password})
        if client.cookies
          session = client.cookies.select{|c| c.name == 'session'}.first
          set_cookie(session.name, session.value, url) if session
        end
      end
    end

  private

    def set_cookie(name, value, url)
      cookie = WebAgent::Cookie.new
      cookie.url = URI.parse(sprintf(BASE_URI, url))
      cookie.name = name
      cookie.value = value
      @cookie_manager.add(cookie)
    end

    def parse_csv(csv_url)
      result = []

      data = http_get(csv_url)
      csv_ar = CSV.parse(data.body.gsub(/\"/, ''), col_sep: ';')
      csv_ar.each_index do |i|
        next if i == 0
        row_data = {}
        sum = 0
        begin
          row_date = Date.parse("#{csv_ar[i].first} #{Date.today.year}")
          next if row_date != date_to
          row_data = {date: row_date}
          csv_ar.first.each_index do |head_i|
            next if head_i == 0
            head_code = csv_ar.first[head_i]
            value = csv_ar[i][head_i].to_f
            row_data.merge!({head_code => value})
            sum += value
          end
        rescue Exception => e
          row_data = {date: e}
        end
        result << row_data if sum > 0
      end
      result
    rescue CSV::MalformedCSVError => e
      puts e.inspect
      result
    end

    def base_read(url)
      uri = sprintf(BASE_URI, url)
      message = http_get(uri)
      [message, uri]
    end

    def http_get(url)
      data = @http.get(url)
      if data.status == 302
        html = data.body
        doc = Nokogiri::HTML(html)
        uri = doc.xpath('//a/@href').first.value
        @http.get(uri)
      else
        data
      end
    end

  end
end

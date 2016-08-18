require 'json'
require 'net/http'

# allsocial.ru parser
# 
# Author:: Laushkin Dmitriy (mailto:mr.rufoos@gmail.com)

module Allsocial

  OFFSET_STEP = 25

  def self.parse(url, opt = {})
    offset = opt[:offset] ? opt[:offset] : 0
    total_count = offset + 1 # enter to while

    while offset < total_count do
      uri = URI(sprintf(url, offset))
      data = Net::HTTP.get(uri)
      json_data = JSON.parse(data)
      total_count = json_data['response']['total_count'].to_i if total_count == offset + 1

      yield json_data if block_given?

      Rails.env.development? ? offset = total_count : offset += OFFSET_STEP
      sleep(0.5)
    end
  end

  def self.parse_admins_with_our_platforms(offset = nil)
    self.parse "http://allsocial.ru/get-admins?direction=1&offset=%d&order_by=membersSum&period=day&platform=1", offset: offset do |data|
      write_to_tbl(:allsocial_admins, data['response']['admin'])
      admin_ids = data['response']['admin'].map{ |a| a['vk_id'] }
      admin_ids.each do |admin_id|
        self.parse "http://allsocial.ru/entity?direction=1&is_closed=-1&is_verified=-1&list_type=1&order_by=diff_abs&period=day&platform=1&range=0:8000000&offset=%d&str=admin:#{admin_id}&type_id=-1" do |data|
          data_with_admin_id = data['response']['entity'].tap do |entities|
            entities.delete_if{ |entity| entity['quantity'].to_i < 1000 }.each{ |entity| entity['admin_id'] = admin_id }
          end
          write_to_tbl(:allsocial_platforms, data_with_admin_id) unless data_with_admin_id.empty?
        end
      end
    end
  end

  def self.parse_platforms
    self.parse "http://allsocial.ru/entity?direction=1&is_closed=-1&is_verified=-1&list_type=1&offset=%d&order_by=quantity&period=day&platform=1&range=0:8000000&type_id=1" do |data|
      write_to_tbl(:allsocial_platforms, data['response']['entity'])
    end
  end

  def self.write_to_tbl(tbl, data)

    # VALUES
    joined_values = []
    data.each do |line|
      values = []
      line.each do |key, value|
        values <<
          if value.is_a?(String)
            if key == 'caption' || key == 'name'
              "'#{ActiveRecord::Base.connection.quote_string(value.gsub(/[^\p{Word}\p{Space}-\/\\|_]/, '-'))}'"
            else
              "'#{ActiveRecord::Base.connection.quote_string(value)}'"
            end
          elsif value.is_a?(Hash)
            value.values.map{ |v| "'#{v.join(',')}'" }
          else
            value
          end
      end
      joined_values << "( #{values.flatten.join(',')} )"
    end

    # FIELDS
    fields = []
    data.first.each do |key, value|
      fields <<
        if value.is_a?(Hash)
          value.keys.map{ |k| "`#{key.underscore}_#{k}`" }
        else
          "`#{key.underscore}`"
        end
    end
    fields = fields.flatten

    # QUERY
    query = "INSERT INTO `#{tbl}` (#{ fields.join(',') }) VALUES #{joined_values.join(',')} ON DUPLICATE KEY UPDATE #{fields.map{ |f| "#{f} = VALUES(#{f})" }.join(',')}"

    # EXEC
    ActiveRecord::Base.connection.execute(query)
  end

end
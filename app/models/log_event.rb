class LogEvent
  include Mongoid::Document
  include Mongoid::Timestamps
  field :params, type: Hash
  field :item_type, type: String
  field :item_id, type: Integer
  field :event, type: String
  field :user_id, type: Integer

  scope :existed, ->{ where(:user_id.ne => nil, :item_type.ne => nil, :item_id.ne => nil) }
  scope :filter, ->(params){
    where_q = {}
    params.each do |p, value|
      next unless value.present?
      case p
      when 'user_id'
        where_q.merge!(user_id: value)
      end
    end
    existed.where(where_q).order_by([:created_at, :desc])
  }

  def self.events
    self.methods.select{|m| m.to_s.index(/^event_/)}
  end

  def self.event_all(params)
    existed.order_by([:created_at, :asc])
  end

  def self.event_registrations(params)
    filter(params).where(:item_type => 'User')
  end

  def self.event_campaigns(params)
    if params[:platform_id].present?
      campaign_ids = LogEvent.filter(params).where(:item_type => 'CampaignPlatform', 'params.platform_id' => params[:platform_id]).map{|p| p.params[:id]}
      filter(params).where(:item_type => 'Campaign').in('params.id' => campaign_ids)
    else
      filter(params).where(:item_type => 'Campaign')
    end
  end

  def self.event_users(params)
    filter(params).where(:item_type => 'User')
  end

  def self.event_reposts(params)
  end

  def self.event_platform_added_rotator(params)
    filter(params).where(:item_type => 'Platform').in('params.with_rotator' => false)
  end

  def self.event_platform_delete_rotator(params)
    filter(params).where(:item_type => 'Platform').in('params.with_rotator' => true)
  end
end
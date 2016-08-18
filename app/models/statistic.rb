class Statistic
  attr_reader :user, :model_name, :model, :id, :range

  PER_PAGE = 100
  STAT_URL_LI = "http://liveinternet.ru/stat/%s"
  STAT_URL_YM = 'https://metrika.yandex.ru/stat/dashboard/?counter_id=%s'
  STAT_URL_GA = 'https://www.google.com/analytics'
  # STAT_URL_GA = 'https://www.google.com/analytics/web/?hl=en#report/visitors-overview/a43335836w89949928p93507960/'
  # STAT_URL_GA = 'https://www.google.com/analytics/web/?hl=en#report/visitors-overview/%s/'
  STAT_URL_VK = "http://vk.com/stats?gid=%s"
  DATE_FILTERS = [
    "all",
    "today",
    "yesterday",
    "this_week",
    "previous_week",
    "this_month",
    "previous_month",
    "previous_3months",
    "this_year",
    "previous_year"
  ]

  def initialize(user, model_name)
    @user = user
    if %w(campaigns platforms).include?(model_name)
      @model_name = model_name
      @model = eval(@model_name.classify)
    end
  end

  def filter(options = {})
    parse_options(options)
    platform_ids = options[:platforms].nil? || options[:platforms].empty? ? nil : options[:platforms].split(',').map(&:to_i)
    q_where = []
    q_where << CampaignStatDay.arel_table[:platform_id].in(platform_ids).to_sql if platform_ids
    q_where << Campaign.arel_table[:title].matches("#{options[:campaign_name]}%").to_sql if options[:campaign_name].present?

    if options[:grouped].present?
      CampaignStatDay.for(user).send("#{model_name}_#{options[:grouped]}").where(date: range).where(q_where.join(' AND '))
    else
      CampaignStatDay.for(user).send(model_name).where(date: range).where(q_where.join(' AND ')).page(options[:page]).per(PER_PAGE)
    end
  end

  def filter_by_id(id, options = {})
    parse_options(options)
    stat_scope = {campaigns: :platforms_by_campaign, platforms: :campaigns_by_platform}
    CampaignStatDay.for(user).send(stat_scope[model_name.to_sym], id).where(date: range)
  end

  def filter_for_model(id, options = {})
    parse_options(options)
    CampaignStatDay.for(user).send(model_name, id).where(date: range)
  end

private

  def parse_options(options)
    options = options.symbolize_keys
    filter_name = DATE_FILTERS.include?(options[:name]) ? options[:name] : nil
    if options[:date_from].present? && options[:date_to].present?
      begin
        date_from = Date.parse(options[:date_from])
        date_to = Date.parse(options[:date_to])
      rescue Exception => e
        date_from, date_to = nil, nil
      end
    end
    @range = if filter_name
      self.send("#{filter_name}_range")
    elsif date_from && date_to
      date_from..date_to
    else
      all_range
    end
  end

  def today_range
    Date.today
  end

  def yesterday_range
    Date.yesterday
  end

  def all_range
    range = CampaignStatDay.select("MIN(date) AS min_date, MAX(date) AS max_date").first
    range.min_date..range.max_date
  end

  def this_week_range
    Date.today.beginning_of_week..Date.today
  end

  def previous_week_range
    previous_week_day = Date.today.beginning_of_week - 1.day
    previous_week_day.beginning_of_week..previous_week_day.end_of_week
  end

  def this_month_range
    Date.today.beginning_of_month..Date.today
  end

  def previous_month_range
    prev_day_month = Date.today.beginning_of_month - 1.day
    prev_day_month.beginning_of_month..prev_day_month.end_of_month
  end

  def previous_3months_range
    beginning = Date.today.beginning_of_month - 3.month
    ending = Date.today.beginning_of_month
    beginning..ending
  end

  def this_year_range
    Date.today.beginning_of_year..Date.today
  end

  def previous_year_range
    prev_day_year = Date.today.beginning_of_year - 1.day
    prev_day_year.beginning_of_year..prev_day_year
  end

end
class ServiceOffering
  attr_reader :plans
  attr_accessor :guid

  def initialize(attrs)
    offering = {}
    %w(unique_id version provider url description).each { |k| offering[k] = attrs.fetch(k.to_sym) }
    %w(active acls timeout extra).each { |k| offering[k] = attrs[k.to_sym] }

    offering['label'] = attrs[:label] || attrs.fetch(:name)

    offering_plans = []
    plans = attrs[:plans]
    if plans
      plans.each_pair { |name, p|
        offering_plan = {}
        offering_plan['name'] = name
        %w(unique_id description free extra).each { |k| offering_plan[k] = p.fetch(k.to_sym) }


        offering_plan['guid'] = p[:guid] if p.has_key? :guid

        offering_plans << offering_plan
      }
    end


    @guid = attrs[:guid] if attrs.has_key? :guid

    @plans = offering_plans
    @offering = offering
  end

  def [](key)
    @offering[key]
  end

  def to_hash
    @offering
  end

end
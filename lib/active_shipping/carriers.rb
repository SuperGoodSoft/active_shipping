module ActiveShipping
  module Carriers
    extend self

    attr_reader :registered
    @registered = []

    def register(class_name, autoload_require)
      ActiveShipping.autoload(class_name, autoload_require)
      self.registered << class_name
    end

    def all
      ActiveShipping::Carriers.registered.map { |name| ActiveShipping.const_get(name) }
    end

    def find(name)
      all.find { |c| c.name.downcase == name.to_s.downcase } or raise NameError, "unknown carrier #{name}"
    end
  end
end

ActiveShipping::Carriers.register :USPS,             'active_shipping/carriers/usps'
ActiveShipping::Carriers.register :USPSReturns,      'active_shipping/carriers/usps_returns'
ActiveShipping::Carriers.register :UPS,              'active_shipping/carriers/ups'

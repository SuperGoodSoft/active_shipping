require 'builder'

module ActiveShipping
  class UPS < Carrier
    self.retry_safe = true
    self.ssl_version = :TLSv1_2

    cattr_reader :name
    @@name = "UPS"

    TEST_URL = 'https://wwwcie.ups.com/ups.app/xml'
    LIVE_URL = 'https://onlinetools.ups.com/ups.app/xml'

    RESOURCES = {
      :rates => 'Rate',
      :track => 'Track',
      :ship_confirm => 'ShipConfirm',
      :ship_accept => 'ShipAccept',
      :ship_void => 'Void'
    }

    PICKUP_CODES = {
      :daily_pickup => "01",
      :customer_counter => "03",
      :one_time_pickup => "06",
      :on_call_air => "07",
      :suggested_retail_rates => "11",
      :letter_center => "19",
      :air_service_center => "20"
    }

    CUSTOMER_CLASSIFICATIONS = {
      :wholesale => "01",
      :occasional => "03",
      :retail => "04"
    }

    # These are the service codes that are used in the UPS API
    SERVICE_CODES = {
      "01" => "UPS Next Day Air",
      "02" => "UPS Second Day Air",
      "03" => "UPS Ground",
      "07" => "UPS Worldwide Express",
      "08" => "UPS Worldwide Expedited",
      "11" => "UPS Standard",
      "12" => "UPS Three-Day Select",
      "13" => "UPS Next Day Air Saver",
      "14" => "UPS Next Day Air Early A.M.",
      "54" => "UPS Worldwide Express Plus",
      "59" => "UPS Second Day Air A.M.",
      "65" => "UPS Saver",
      "M2" => "UPS First-Class Mail",
      "M3" => "UPS Priority Mail",
      "M4" => "UPS Expedited Mail Innovations",
      "M5" => "UPS Priority Mail Innovations",
      "M6" => "UPS Economy Mail Innovations",
      "82" => "UPS Today Standard",
      "83" => "UPS Today Dedicated Courier",
      "84" => "UPS Today Intercity",
      "85" => "UPS Today Express",
      "86" => "UPS Today Express Saver"
    }

    # From UPS Developer Guide
    PACKAGING_TYPES = {
      "00" => "UNKNOWN",
      "01" => "UPS Letter",
      "02" => "Package",
      "03" => "Tube",
      "04" => "Pak",
      "21" => "UPS Express Box",
      "24" => "UPS 25KG Box",
      "25" => "UPS 10KG Box",
      "30" => "Pallet",
      "2a" => "Small Express Box",
      "2b" => "Medium Express Box",
      "2c" => "Large Express Box"
    }

    DEFAULT_SERVICES = %w[03]  # UPS Ground

    def requirements
      [:key, :login, :password]
    end

    def find_rates(origin, destination, packages, options = {})
      origin, destination = upsified_location(origin), upsified_location(destination)
      
      packages = Array(packages)
      access_request = build_access_request
      rate_request = build_rate_request(origin, destination, packages, options)
      
      response = commit(:rates, save_request(access_request + rate_request))
      
      parse_rate_response(origin, destination, packages, response, options)
    end

    def valid_credentials?
      location = Location.new(
        :country => 'US',
        :state => 'CA',
        :city => 'Los Angeles',
        :zip => '90210'
      )
      
      packages = [Package.new(1, [1, 1, 1], :units => :imperial)]
      
      begin
        find_rates(location, location, packages)
      rescue ActiveShipping::ResponseError
        return false
      end
      
      true
    rescue ActiveShipping::ResponseError => e
      e.message !~ /^#{INVALID_CREDENTIALS_MESSAGE}$/
    end

    protected

    def upsified_location(location)
      if location.country_code == 'US' && !location.state_code.blank?
        Location.new(location.to_hash.merge(:state => location.state_code.upcase))
      else
        location
      end
    end

    def build_access_request
      xml = Builder::XmlMarkup.new
      xml.instruct!
      xml.AccessRequest do
        xml.AccessLicenseNumber(@options[:key])
        xml.UserId(@options[:login])
        xml.Password(@options[:password])
      end
      xml.target!
    end

    def build_rate_request(origin, destination, packages, options = {})
      xml = Builder::XmlMarkup.new
      xml.instruct!
      xml.RatingServiceSelectionRequest do
        xml.Request do
          xml.RequestAction('Rate')
          xml.RequestOption(options[:service].nil? ? 'Shop' : 'Rate')
        end
        
        xml.PickupType do
          xml.Code(options[:pickup_type] || PICKUP_CODES[:daily_pickup])
        end
        
        xml.CustomerClassification do
          xml.Code(options[:customer_classification] || CUSTOMER_CLASSIFICATIONS[:wholesale])
        end
        
        xml.Shipment do
          xml.Shipper do
            build_location_node(xml, origin, options)
          end
          
          xml.ShipTo do
            build_location_node(xml, destination, options)
          end
          
          if options[:shipper] && options[:shipper] != origin
            xml.ShipFrom do
              build_location_node(xml, options[:shipper], options)
            end
          else
            xml.ShipFrom do
              build_location_node(xml, origin, options)
            end
          end
          
          # Service Type
          if options[:service]
            xml.Service do
              xml.Code(options[:service])
            end
          end
          
          packages.each do |package|
            xml.Package do
              xml.PackagingType do
                xml.Code(options[:packaging_type] || "02")
              end
              
              xml.Dimensions do
                xml.UnitOfMeasurement do
                  xml.Code(package.inches? ? 'IN' : 'CM')
                end
                [:length, :width, :height].each do |attr|
                  value = package.send(attr)
                  xml.send(attr.to_s.capitalize, value.to_f.round(2).to_s) if value
                end
              end
              
              xml.PackageWeight do
                xml.UnitOfMeasurement do
                  xml.Code(package.pounds? ? 'LBS' : 'KGS')
                end
                xml.Weight(package.weight.to_f.round(2).to_s)
              end
              
              if package.value && package.value > 0
                xml.PackageServiceOptions do
                  xml.DeclaredValue do
                    xml.CurrencyCode(package.currency || 'USD')
                    xml.MonetaryValue(package.value.to_f.round(2).to_s)
                  end
                end
              end
            end
          end
        end
      end
      xml.target!
    end

    def build_location_node(xml, location, options = {})
      xml.Address do
        xml.AddressLine1(location.address1) unless location.address1.blank?
        xml.AddressLine2(location.address2) unless location.address2.blank?
        xml.AddressLine3(location.address3) unless location.address3.blank?
        xml.City(location.city) unless location.city.blank?
        xml.StateProvinceCode(location.state) unless location.state.blank?
        xml.PostalCode(location.postal_code) unless location.postal_code.blank?
        xml.CountryCode(location.country_code(:alpha2)) unless location.country_code(:alpha2).blank?
        xml.ResidentialAddressIndicator('1') if location.residential?
      end
    end

    def parse_rate_response(origin, destination, packages, response, options = {})
      rates = []
      
      xml = Nokogiri::XML(response, &:strict)
      
      if error = xml.at('RatingServiceSelectionResponse/Response/Error')
        error_code = error.at('ErrorCode').text
        error_description = error.at('ErrorDescription').text
        raise ResponseError.new("#{error_code}: #{error_description}")
      end
      
      xml.xpath('RatingServiceSelectionResponse/RatedShipment').each do |rated_shipment|
        service_code = rated_shipment.at('Service/Code').text
        service_name = SERVICE_CODES[service_code] || "Unknown Service"
        
        # Skip if not a requested service
        if options[:service]
          next unless service_code == options[:service]
        elsif options[:services]
          next unless options[:services].include?(service_code)
        else
          next unless DEFAULT_SERVICES.include?(service_code)
        end
        
        total_price = rated_shipment.at('TotalCharges/MonetaryValue').text.to_f
        currency = rated_shipment.at('TotalCharges/CurrencyCode').text
        
        rates << RateEstimate.new(
          origin,
          destination,
          @@name,
          service_name,
          :total_price => (total_price * 100).to_i,
          :currency => currency,
          :service_code => service_code,
          :packages => packages
        )
      end
      
      RateResponse.new(
        true,
        "Rates retrieved successfully",
        {:request => last_request, :response => response},
        :rates => rates
      )
    end

    def commit(action, request)
      url = test_mode? ? TEST_URL : LIVE_URL
      url += "/#{RESOURCES[action]}"
      
      response = ssl_post(url, request)
      response
    rescue ActiveShipping::ResponseError => e
      raise e
    rescue => e
      raise ResponseError.new(e.message)
    end
  end
end
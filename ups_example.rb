#!/usr/bin/env ruby

require 'bundler/setup'
require 'active_shipping'

# Initialize UPS carrier
# Note: Replace with your actual UPS API credentials
ups = ActiveShipping::UPS.new(
  key: ENV['UPS_KEY'] || 'YOUR_ACCESS_KEY',
  login: ENV['UPS_LOGIN'] || 'YOUR_USERNAME',
  password: ENV['UPS_PASSWORD'] || 'YOUR_PASSWORD',
  test: true
)

# Origin address
origin = ActiveShipping::Location.new(
  country: 'US',
  state: 'CA',
  city: 'Los Angeles',
  zip: '90001'
)

# Destination address
destination = ActiveShipping::Location.new(
  country: 'US',
  state: 'NY',
  city: 'New York',
  zip: '10001'
)

# Package: 10 lbs, 12x10x8 inches
package = ActiveShipping::Package.new(
  10 * 16,          # 10 pounds in ounces
  [12, 10, 8],      # dimensions in inches
  units: :imperial
)

begin
  # Request UPS Ground rates (service code "03")
  response = ups.find_rates(origin, destination, package, service: "03")
  
  if response.success?
    rate = response.rates.first
    puts "UPS Ground Rate:"
    puts "  From: #{origin.city}, #{origin.state}"
    puts "  To: #{destination.city}, #{destination.state}"
    puts "  Package: #{package.pounds} lbs"
    puts "  Price: $#{'%.2f' % (rate.price.to_f / 100)}"
  else
    puts "Error: #{response.message}"
  end
rescue ActiveShipping::ResponseError => e
  puts "UPS API Error: #{e.message}"
  puts "\nPlease set your UPS credentials:"
  puts "  export UPS_KEY='your_key'"
  puts "  export UPS_LOGIN='your_login'"
  puts "  export UPS_PASSWORD='your_password'"
end
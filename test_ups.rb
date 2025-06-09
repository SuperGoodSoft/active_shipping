#!/usr/bin/env ruby

require 'bundler/setup'
require 'active_shipping'

# Test script to verify UPS Ground rate calculation

# Create UPS carrier instance
# Note: You'll need to replace these with your actual UPS API credentials
ups = ActiveShipping::UPS.new(
  key: ENV['UPS_KEY'] || 'YOUR_UPS_ACCESS_KEY',
  login: ENV['UPS_LOGIN'] || 'YOUR_UPS_USERNAME', 
  password: ENV['UPS_PASSWORD'] || 'YOUR_UPS_PASSWORD',
  test: true  # Use test mode
)

# Define origin location
origin = ActiveShipping::Location.new(
  country: 'US',
  state: 'CA',
  city: 'Los Angeles',
  zip: '90001',
  address1: '123 Main St',
  address_type: 'commercial'
)

# Define destination location  
destination = ActiveShipping::Location.new(
  country: 'US',
  state: 'NY',
  city: 'New York',
  zip: '10001',
  address1: '456 Broadway',
  address_type: 'residential'
)

# Create a package (10 lbs, 12x10x8 inches)
package = ActiveShipping::Package.new(
  10 * 16,  # weight in ounces (10 lbs)
  [12, 10, 8],  # dimensions in inches
  units: :imperial,
  value: 100.00,  # declared value
  currency: 'USD'
)

begin
  puts "Testing UPS rate calculation..."
  puts "Origin: #{origin.city}, #{origin.state} #{origin.zip}"
  puts "Destination: #{destination.city}, #{destination.state} #{destination.zip}"
  puts "Package: #{package.pounds} lbs, #{package.inches.join('x')} inches"
  puts "-" * 50
  
  # Example 1: Request only UPS Ground (service code "03")
  puts "\n1. Requesting only UPS Ground rates:"
  response = ups.find_rates(origin, destination, package, service: "03")
  
  if response.success?
    puts "Successfully retrieved rates!"
    puts "-" * 50
    
    response.rates.sort_by(&:price).each do |rate|
      puts "Service: #{rate.service_name}"
      puts "Price: $#{rate.price.to_f / 100}"
      puts "Delivery: #{rate.delivery_date}" if rate.delivery_date
      puts "-" * 50
    end
  else
    puts "Error: #{response.message}"
  end
  
  # Example 2: Request multiple specific services
  puts "\n2. Requesting UPS Ground, 2-Day, and Next Day Air:"
  response2 = ups.find_rates(origin, destination, package, services: ["03", "02", "01"])
  
  if response2.success?
    response2.rates.sort_by(&:price).each do |rate|
      puts "Service: #{rate.service_name} (#{rate.service_code})"
      puts "Price: $#{rate.price.to_f / 100}"
      puts "-" * 50
    end
  end
  
  # Example 3: Request all available services (shop for rates)
  puts "\n3. Requesting all available UPS services:"
  response3 = ups.find_rates(origin, destination, package, services: ActiveShipping::UPS::SERVICE_CODES.keys)
  
  if response3.success?
    puts "Found #{response3.rates.length} available services:"
    response3.rates.sort_by(&:price).each do |rate|
      puts "Service: #{rate.service_name} (#{rate.service_code})"
      puts "Price: $#{rate.price.to_f / 100}"
      puts "-" * 50
    end
  end
  
rescue ActiveShipping::ResponseError => e
  puts "Error communicating with UPS: #{e.message}"
  puts "\nMake sure to set your UPS API credentials:"
  puts "  export UPS_KEY='your_access_key'"
  puts "  export UPS_LOGIN='your_username'"
  puts "  export UPS_PASSWORD='your_password'"
rescue => e
  puts "Unexpected error: #{e.class} - #{e.message}"
  puts e.backtrace.first(5)
end
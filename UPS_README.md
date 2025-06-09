# UPS Carrier for ActiveShipping

This document describes how to use the restored UPS carrier implementation to calculate shipping rates.

## Setup

### 1. UPS Developer Account

To use the UPS carrier, you need to obtain API credentials from UPS:

1. Sign up for a UPS developer account at https://www.ups.com/upsdeveloperkit
2. Get your Access Key, User ID, and Password
3. Test your credentials in the UPS test environment before going to production

### 2. Configuration

Initialize the UPS carrier with your credentials:

```ruby
ups = ActiveShipping::UPS.new(
  key: 'YOUR_UPS_ACCESS_KEY',
  login: 'YOUR_UPS_USERNAME',
  password: 'YOUR_UPS_PASSWORD',
  test: true  # Set to false for production
)
```

## Basic Usage

### Calculate UPS Ground Rates

```ruby
# Define origin
origin = ActiveShipping::Location.new(
  country: 'US',
  state: 'CA',
  city: 'Los Angeles',
  zip: '90001',
  address1: '123 Main St',
  address_type: 'commercial'
)

# Define destination
destination = ActiveShipping::Location.new(
  country: 'US',
  state: 'NY',
  city: 'New York',
  zip: '10001',
  address1: '456 Broadway',
  address_type: 'residential'
)

# Create package
package = ActiveShipping::Package.new(
  160,  # weight in ounces (10 lbs)
  [12, 10, 8],  # dimensions in inches
  units: :imperial,
  value: 100.00,
  currency: 'USD'
)

# Get UPS Ground rate (service code "03")
response = ups.find_rates(origin, destination, package, service: "03")

if response.success?
  response.rates.each do |rate|
    puts "#{rate.service_name}: $#{rate.price.to_f / 100}"
  end
end
```

## Service Codes

Common UPS service codes:

- `"01"` - UPS Next Day Air
- `"02"` - UPS Second Day Air
- `"03"` - UPS Ground
- `"12"` - UPS Three-Day Select
- `"13"` - UPS Next Day Air Saver
- `"14"` - UPS Next Day Air Early A.M.
- `"59"` - UPS Second Day Air A.M.

## Advanced Usage

### Request Multiple Services

```ruby
# Get rates for Ground, 2-Day, and Next Day
services = ["03", "02", "01"]
response = ups.find_rates(origin, destination, package, services: services)
```

### Request All Available Services

```ruby
# Shop for all available rates
all_services = ActiveShipping::UPS::SERVICE_CODES.keys
response = ups.find_rates(origin, destination, package, services: all_services)
```

### Packaging Types

Specify package type (default is "02" - Package):

```ruby
response = ups.find_rates(origin, destination, package, 
  service: "03",
  packaging_type: "02"  # Regular package
)
```

Available packaging types:
- `"01"` - UPS Letter
- `"02"` - Package (default)
- `"03"` - Tube
- `"04"` - Pak
- `"21"` - UPS Express Box
- `"24"` - UPS 25KG Box
- `"25"` - UPS 10KG Box

### Pickup Types

Specify how packages will be picked up:

```ruby
response = ups.find_rates(origin, destination, package,
  pickup_type: :daily_pickup  # Default
)
```

Options:
- `:daily_pickup` - Daily pickup (default)
- `:customer_counter` - Customer counter
- `:one_time_pickup` - One-time pickup
- `:on_call_air` - On call air
- `:suggested_retail_rates` - Suggested retail rates

### Multiple Packages

```ruby
packages = [
  ActiveShipping::Package.new(160, [12, 10, 8], units: :imperial),
  ActiveShipping::Package.new(80, [10, 8, 6], units: :imperial)
]

response = ups.find_rates(origin, destination, packages)
```

## Error Handling

```ruby
begin
  response = ups.find_rates(origin, destination, package)
  
  if response.success?
    # Process rates
  else
    puts "Error: #{response.message}"
  end
rescue ActiveShipping::ResponseError => e
  puts "UPS API Error: #{e.message}"
rescue => e
  puts "Unexpected error: #{e.message}"
end
```

## Testing

To run the included test script:

```bash
# Set environment variables
export UPS_KEY='your_access_key'
export UPS_LOGIN='your_username'
export UPS_PASSWORD='your_password'

# Run test
ruby test_ups.rb
```

## Limitations

This implementation currently supports:
- Rate calculation (find_rates)
- UPS Ground and other standard services
- Domestic US shipments

Not yet implemented:
- International shipping
- Tracking (find_tracking_info)
- Label generation (create_shipment)
- Address validation
- Time-in-transit estimates

## Troubleshooting

1. **Invalid credentials error**: Verify your UPS API credentials are correct and active
2. **No rates returned**: Check that the service codes you're requesting are available for your origin/destination pair
3. **Test mode issues**: Ensure you're using test credentials when `test: true`

## Contributing

To add more UPS functionality:

1. Extend the `lib/active_shipping/carriers/ups.rb` file
2. Add appropriate service codes to `SERVICE_CODES`
3. Implement additional API methods following the carrier interface
4. Add tests for new functionality
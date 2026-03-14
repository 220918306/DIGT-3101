class UtilityService
  ELECTRICITY_RATE = 0.12  # per kWh
  WATER_RATE       = 0.003 # per gallon
  WASTE_FLAT_FEE   = 50.0

  # FR-11: Retrieve utility charges for a lease period
  def get_charges(lease_id, billing_period)
    consumption = UtilityConsumption.find_or_create_by(
      lease_id:       lease_id,
      billing_period: billing_period
    ) do |c|
      sim = simulate_consumption
      c.electricity_usage = sim[:electricity_usage]
      c.water_usage        = sim[:water_usage]
      c.waste_charge       = WASTE_FLAT_FEE
      c.electricity_charge = (sim[:electricity_usage] * ELECTRICITY_RATE).round(2)
      c.water_charge       = (sim[:water_usage] * WATER_RATE).round(2)
    end

    {
      electricity: (consumption.electricity_usage * ELECTRICITY_RATE).round(2),
      water:       (consumption.water_usage * WATER_RATE).round(2),
      waste:       WASTE_FLAT_FEE,
      total:       calculate_total(consumption)
    }
  end

  private

  def simulate_consumption
    {
      electricity_usage: rand(500..2000).to_f,
      water_usage:       rand(1000..5000).to_f
    }
  end

  def calculate_total(c)
    ((c.electricity_usage * ELECTRICITY_RATE) +
     (c.water_usage * WATER_RATE) +
     WASTE_FLAT_FEE).round(2)
  end
end

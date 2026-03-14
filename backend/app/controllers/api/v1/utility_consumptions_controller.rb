class Api::V1::UtilityConsumptionsController < Api::V1::BaseController
  # GET /api/v1/utility_consumptions — FR-11: View utility usage history
  def index
    consumptions = if current_user.tenant?
                     lease_ids = Lease.where(tenant_id: current_user.tenant.id).pluck(:id)
                     UtilityConsumption.where(lease_id: lease_ids).order(billing_period: :desc)
                   else
                     UtilityConsumption.includes(:lease).order(billing_period: :desc)
                   end
    render json: consumptions.map { |c| consumption_json(c) }
  end

  # GET /api/v1/utility_consumptions/:id — FR-12: Detailed utility breakdown
  def show
    consumption = UtilityConsumption.find(params[:id])
    render json: consumption_json(consumption)
  end

  private

  def consumption_json(c)
    {
      id:                 c.id,
      lease_id:           c.lease_id,
      billing_period:     c.billing_period,
      electricity_usage:  c.electricity_usage,
      electricity_charge: c.electricity_charge,
      water_usage:        c.water_usage,
      water_charge:       c.water_charge,
      waste_charge:       c.waste_charge,
      total_charge:       (c.electricity_charge.to_f + c.water_charge.to_f + c.waste_charge.to_f).round(2)
    }
  end
end

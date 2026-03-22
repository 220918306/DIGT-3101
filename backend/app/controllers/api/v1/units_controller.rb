class Api::V1::UnitsController < Api::V1::BaseController
  # GET /api/v1/units — FR-01: Search & filter available units
  def index
    units = Unit.includes(:property)
    units = units.where(status: "available") if params[:available_only] == "true"
    units = units.where("rental_rate >= ?", params[:min_price].to_f) if params[:min_price].present?
    units = units.where("rental_rate <= ?", params[:max_price].to_f) if params[:max_price].present?
    units = units.where("size >= ?", params[:min_size].to_f) if params[:min_size].present?
    units = units.where("size <= ?", params[:max_size].to_f) if params[:max_size].present?
    units = units.where(tier: params[:tier]) if params[:tier].present?
    units = units.where(purpose: params[:purpose]) if params[:purpose].present?

    render json: units.map { |u| unit_json(u) }
  end

  # GET /api/v1/units/:id — FR-02: View unit details
  def show
    unit = Unit.includes(:property).find(params[:id])
    render json: unit_json(unit)
  end

  # POST /api/v1/units — Staff creates a new unit record
  def create
    authorize_roles!("clerk", "admin")
    unit = Unit.create!(unit_params)
    render json: unit_json(unit), status: :created
  end

  # PATCH /api/v1/units/:id — Staff updates unit management details
  def update
    authorize_roles!("clerk", "admin")
    unit = Unit.find(params[:id])
    unit.update!(unit_params)
    render json: unit_json(unit)
  end

  # GET /api/v1/units/:id/available_slots — FR-03: Show open time slots
  def available_slots
    date  = Date.parse(params[:date])
    slots = SchedulingService.new.available_slots(params[:id], date)
    render json: { date: date, available_slots: slots }
  rescue Date::Error
    render json: { error: "Invalid date format" }, status: :bad_request
  end

  private

  def unit_params
    params.permit(:property_id, :unit_number, :size, :rental_rate, :tier, :purpose, :status, :available)
  end

  def unit_json(u)
    {
      id:          u.id,
      property_id: u.property_id,
      unit_number: u.unit_number,
      size:        u.size,
      rental_rate: u.rental_rate,
      tier:        u.tier,
      purpose:     u.purpose,
      status:      u.status,
      available:   u.available,
      property:    { id: u.property.id, name: u.property.name, address: u.property.address }
    }
  end
end

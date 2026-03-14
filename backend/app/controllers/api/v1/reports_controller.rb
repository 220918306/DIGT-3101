class Api::V1::ReportsController < Api::V1::BaseController
  before_action -> { authorize_roles!("admin", "clerk") }

  # GET /api/v1/reports/occupancy — FR-10: Occupancy report
  def occupancy
    total          = Unit.count
    occupied_count = Unit.where(status: "occupied").count
    available_count = Unit.where(status: "available").count
    maintenance_count = Unit.where(status: "under_maintenance").count

    render json: {
      total_units:       total,
      occupied_units:    occupied_count,
      available_units:   available_count,
      maintenance_units: maintenance_count,
      occupancy_rate:    total > 0 ? ((occupied_count.to_f / total) * 100).round(2) : 0,
      breakdown_by_tier: tier_breakdown
    }
  end

  # GET /api/v1/reports/revenue — FR-10: Revenue report
  def revenue
    start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : 30.days.ago.to_date
    end_date   = params[:end_date].present?   ? Date.parse(params[:end_date])   : Date.today

    paid_invoices    = Invoice.where(status: "paid", updated_at: start_date.beginning_of_day..end_date.end_of_day)
    pending_invoices = Invoice.where(status: %w[unpaid partially_paid])

    render json: {
      total_revenue:       paid_invoices.sum(:amount_paid).round(2),
      invoice_count:       paid_invoices.count,
      pending_revenue:     pending_invoices.sum { |i| i.remaining_balance }.round(2),
      overdue_amount:      Invoice.where(status: "overdue").sum { |i| i.remaining_balance }.round(2),
      period:              { start: start_date, end: end_date },
      monthly_breakdown:   monthly_revenue_breakdown(start_date, end_date)
    }
  end

  # GET /api/v1/reports/maintenance — FR-10: Maintenance metrics
  def maintenance
    render json: {
      open:           MaintenanceTicket.where(status: "open").count,
      in_progress:    MaintenanceTicket.where(status: "in_progress").count,
      completed:      MaintenanceTicket.where(status: "completed").count,
      cancelled:      MaintenanceTicket.where(status: "cancelled").count,
      emergency:      MaintenanceTicket.where(priority: "emergency", status: %w[open in_progress]).count,
      urgent:         MaintenanceTicket.where(priority: "urgent", status: %w[open in_progress]).count,
      routine:        MaintenanceTicket.where(priority: "routine", status: %w[open in_progress]).count,
      tenant_caused:  MaintenanceTicket.where(is_tenant_caused: true).count,
      avg_resolution_hours: avg_resolution_time
    }
  end

  private

  def tier_breakdown
    Unit.group(:tier).count
  end

  def monthly_revenue_breakdown(start_date, end_date)
    Invoice.where(status: "paid", updated_at: start_date..end_date)
           .group("DATE_TRUNC('month', updated_at)")
           .sum(:amount_paid)
           .transform_keys { |k| k.strftime("%Y-%m") }
  end

  def avg_resolution_time
    completed = MaintenanceTicket.where(status: "completed").where.not(resolved_at: nil)
    return 0 if completed.none?

    total_hours = completed.sum { |t| (t.resolved_at - t.created_at) / 3600 }
    (total_hours / completed.count).round(1)
  end
end

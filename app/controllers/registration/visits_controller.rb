module Registration
  class VisitsController < BaseController
    def index
      authorize Visit
      @visit = Visit.new
      @driver = Driver.new
      @truck = Truck.new
      load_yard_visits
    end

    def create
      authorize Visit, :check_in?

      @driver = find_or_initialize_driver(visit_params.fetch(:driver, {}))
      @truck = find_or_initialize_truck(visit_params.fetch(:truck, {}))

      @visit = Visits::CheckInService.new(driver: @driver, truck: @truck, checked_in_by: current_user).call

      if @visit.persisted?
        redirect_to registration_visits_path, notice: "Check-in registrado com sucesso."
      else
        load_yard_visits
        render :index, status: :unprocessable_content
      end
    end

    private

    def load_yard_visits
      @yard_visits = policy_scope(Visit).in_yard.order(:entered_yard_at)
    end

    def find_or_initialize_driver(attrs)
      cpf = attrs[:cpf]
      return Driver.new(attrs) if cpf.blank?

      Driver.find_by(cpf: Driver.normalize_value_for(:cpf, cpf)) || Driver.new(attrs)
    end

    def find_or_initialize_truck(attrs)
      plate = attrs[:plate]
      return Truck.new(attrs) if plate.blank?

      Truck.find_by(plate: Truck.normalize_value_for(:plate, plate)) || Truck.new(attrs)
    end

    def visit_params
      params.require(:visit).permit(
        driver: %i[cpf name phone notification_channel],
        truck: %i[plate model capacity]
      )
    end
  end
end

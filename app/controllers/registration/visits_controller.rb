module Registration
  class VisitsController < BaseController
    def index
      authorize Visit
      @visit = Visit.new
      @drivers = Driver.active.order(:name)
      @trucks = Truck.active.order(:plate)
      @yard_visits = policy_scope(Visit).in_yard.order(:entered_yard_at)
    end

    def create
      authorize Visit, :check_in?

      driver = Driver.find(visit_params[:driver_id])
      truck = Truck.find(visit_params[:truck_id])
      @visit = Visits::CheckInService.new(driver: driver, truck: truck, checked_in_by: current_user).call

      if @visit.persisted?
        redirect_to registration_visits_path, notice: "Check-in registrado com sucesso."
      else
        @drivers = Driver.active.order(:name)
        @trucks = Truck.active.order(:plate)
        @yard_visits = policy_scope(Visit).in_yard.order(:entered_yard_at)
        render :index, status: :unprocessable_content
      end
    end

    private

    def visit_params
      params.require(:visit).permit(:driver_id, :truck_id)
    end
  end
end

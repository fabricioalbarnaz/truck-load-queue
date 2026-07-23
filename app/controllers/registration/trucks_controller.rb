module Registration
  class TrucksController < BaseController
    before_action :set_truck, only: %i[show edit update destroy]

    def index
      authorize Truck
      @trucks = policy_scope(Truck).order(:plate)
    end

    def lookup
      authorize Truck, :lookup?

      plate = params[:plate]
      truck = plate.present? ? Truck.find_by(plate: Truck.normalize_value_for(:plate, plate)) : nil

      if truck
        render json: { found: true, record: { model: truck.model, capacity: truck.capacity } }
      else
        render json: { found: false }
      end
    end

    def show
      authorize @truck
    end

    def new
      @truck = Truck.new
      authorize @truck
    end

    def create
      @truck = Truck.new(truck_params)
      authorize @truck

      if @truck.save
        redirect_to registration_truck_path(@truck), notice: "Caminhão cadastrado com sucesso."
      else
        render :new, status: :unprocessable_content
      end
    end

    def edit
      authorize @truck
    end

    def update
      authorize @truck

      if @truck.update(truck_params)
        redirect_to registration_truck_path(@truck), notice: "Caminhão atualizado com sucesso."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      authorize @truck
      @truck.destroy
      redirect_to registration_trucks_path, notice: "Caminhão removido com sucesso."
    end

    private

    def set_truck
      @truck = Truck.find(params[:id])
    end

    def truck_params
      params.require(:truck).permit(:plate, :model, :capacity, :active)
    end
  end
end

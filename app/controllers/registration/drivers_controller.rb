module Registration
  class DriversController < BaseController
    before_action :set_driver, only: %i[show edit update destroy]

    def index
      authorize Driver
      @drivers = policy_scope(Driver).order(:name)
    end

    def show
      authorize @driver
    end

    def new
      @driver = Driver.new
      authorize @driver
    end

    def create
      @driver = Driver.new(driver_params)
      authorize @driver

      if @driver.save
        redirect_to registration_driver_path(@driver), notice: "Motorista cadastrado com sucesso."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize @driver
    end

    def update
      authorize @driver

      if @driver.update(driver_params)
        redirect_to registration_driver_path(@driver), notice: "Motorista atualizado com sucesso."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @driver
      @driver.destroy
      redirect_to registration_drivers_path, notice: "Motorista removido com sucesso."
    end

    private

    def set_driver
      @driver = Driver.find(params[:id])
    end

    def driver_params
      params.require(:driver).permit(:name, :cpf, :phone, :notification_channel, :active, truck_ids: [])
    end
  end
end

module QueueScreen
  class VisitsController < BaseController
    def index
      authorize Visit, :finish?
      @loading_visit = policy_scope(Visit).loading.first
      @queue_visits = policy_scope(Visit).queued.order(:order_issued_at)
    end

    def finish
      authorize Visit, :finish?

      visit = Visit.loading.find(params[:id])
      result = Visits::FinishLoadingService.new(visit: visit, finished_by: current_user).call

      if result.errors.empty?
        redirect_to queue_visits_path, notice: "Carregamento finalizado com sucesso."
      else
        redirect_to queue_visits_path, alert: "Não foi possível finalizar o carregamento."
      end
    end
  end
end

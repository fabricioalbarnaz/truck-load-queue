module Expedition
  class VisitsController < BaseController
    def index
      authorize Visit, :issue_order?
      @yard_visits = policy_scope(Visit).in_yard.order(:entered_yard_at)
      @queue_visits = policy_scope(Visit).active_queue
    end

    def issue_order
      authorize Visit, :issue_order?

      visit = Visit.in_yard.find(params[:id])
      result = Visits::IssueOrderService.new(
        visit: visit, order_issued_by: current_user, order_number: order_number_param
      ).call

      if result.errors.empty?
        redirect_to expedition_visits_path, notice: "Ordem de carregamento emitida."
      else
        alert = result.errors.full_messages.to_sentence.presence || "Não foi possível emitir a ordem de carregamento."
        redirect_to expedition_visits_path, alert: alert
      end
    end

    private

    def order_number_param
      params.require(:visit).permit(:order_number)[:order_number]
    end
  end
end

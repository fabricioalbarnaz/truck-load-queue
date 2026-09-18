module Notifications
  class NotifyDriverService
    MESSAGES = {
      your_turn: ->(visit) {
        "#{visit.driver.name}, é a sua vez de carregar! Dirija-se à balança com o caminhão #{visit.truck.plate}."
      },
      get_ready: ->(visit) {
        "#{visit.driver.name}, prepare-se! Você é o próximo a carregar com o caminhão " \
        "#{visit.truck.plate}. Aguarde a chamada e posicione-se para entrar no carregamento."
      }
    }.freeze

    def self.enqueue(visit:, event:)
      SendNotificationJob.perform_later(visit_id: visit.id, event: event.to_s)
    end

    def initialize(visit:, event:)
      @visit = visit
      @event = event.to_sym
    end

    def call
      body = MESSAGES.fetch(@event).call(@visit)
      Dispatcher.new(@visit.driver).deliver(body)
    end
  end
end

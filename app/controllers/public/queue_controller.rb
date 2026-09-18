module Public
  class QueueController < ApplicationController
    layout "public"

    def show
      @loading = Visit.loading.first
      @getting_ready = Visit.getting_ready.first
      @queued = Visit.active_queue.queued
    end
  end
end

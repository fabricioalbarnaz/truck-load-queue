module Public
  class QueueController < ApplicationController
    def show
      @loading = Visit.loading.first
      @queued = Visit.active_queue.queued
    end
  end
end

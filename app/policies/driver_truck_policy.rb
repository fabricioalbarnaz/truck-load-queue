# frozen_string_literal: true

class DriverTruckPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      user&.admin? ? scope.all : scope.none
    end
  end
end

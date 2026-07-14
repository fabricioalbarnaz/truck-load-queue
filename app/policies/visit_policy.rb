# frozen_string_literal: true

class VisitPolicy < ApplicationPolicy
  def index?
    registration_or_admin?
  end

  def check_in?
    registration_or_admin?
  end

  class Scope < Scope
    def resolve
      registration_or_admin? ? scope.all : scope.none
    end

    private

    def registration_or_admin?
      user&.admin? || user&.role?(:registration_operator)
    end
  end

  private

  def registration_or_admin?
    user&.admin? || user&.role?(:registration_operator)
  end
end

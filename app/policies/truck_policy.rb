# frozen_string_literal: true

class TruckPolicy < ApplicationPolicy
  def index?
    registration_or_admin?
  end

  def show?
    registration_or_admin?
  end

  def create?
    registration_or_admin?
  end

  def update?
    registration_or_admin?
  end

  def destroy?
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

# frozen_string_literal: true

class DriverPolicy < ApplicationPolicy
  def index?
    cadastro_or_admin?
  end

  def show?
    cadastro_or_admin?
  end

  def create?
    cadastro_or_admin?
  end

  def update?
    cadastro_or_admin?
  end

  def destroy?
    cadastro_or_admin?
  end

  class Scope < Scope
    def resolve
      cadastro_or_admin? ? scope.all : scope.none
    end

    private

    def cadastro_or_admin?
      user&.admin? || user&.role?(:cadastro)
    end
  end

  private

  def cadastro_or_admin?
    user&.admin? || user&.role?(:cadastro)
  end
end

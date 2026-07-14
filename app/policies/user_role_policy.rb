# frozen_string_literal: true

class UserRolePolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      user&.admin? ? scope.all : scope.none
    end
  end
end

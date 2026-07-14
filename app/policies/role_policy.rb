# frozen_string_literal: true

class RolePolicy < ApplicationPolicy
  # Role::KEYS is fixed reference data (exactly 4 rows) — admins may rename
  # the display label but never create or destroy a role from Avo, since
  # that would desync from Role::KEYS or cascade-delete user_roles.
  def avo_create?
    false
  end

  def avo_destroy?
    false
  end

  class Scope < Scope
    def resolve
      user&.admin? ? scope.all : scope.none
    end
  end
end

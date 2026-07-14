# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  # Avo (the admin panel) is authorized through these instead of the
  # generic actions above, so it never collides with domain-specific
  # policy methods like `check_in?`/`issue_order?`. Every resource is
  # admin-only by default; subclasses only need to override the ones
  # that should be further restricted (e.g. `RolePolicy` disabling
  # `avo_create?`/`avo_destroy?` since roles are fixed reference data).
  def avo_index?
    admin?
  end

  def avo_show?
    admin?
  end

  def avo_create?
    admin?
  end

  def avo_new?
    avo_create?
  end

  def avo_update?
    admin?
  end

  def avo_edit?
    avo_update?
  end

  def avo_destroy?
    admin?
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NoMethodError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :user, :scope
  end

  private

  def admin?
    user&.admin?
  end
end

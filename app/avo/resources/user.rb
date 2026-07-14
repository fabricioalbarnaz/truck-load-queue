class Avo::Resources::User < Avo::BaseResource
  self.icon = "tabler/outline/users"

  def fields
    field :id, as: :id
    field :name, as: :text
    field :email, as: :text
    field :password, as: :password, only_on: [ :new, :edit ], required: false
    field :password_confirmation, as: :password, only_on: [ :new, :edit ], required: false
  end

  # `has_many`/`has_and_belongs_to_many` association fields render an empty
  # lazy-loaded turbo-frame for this has_many-through association in this
  # Avo version — confirmed via a real headless-browser check, not just the
  # raw HTML (see docs/progress.md's Phase 8 deviations). Role assignment
  # happens through the `UserRole` resource instead (create/destroy a
  # user+role pair, using plain `belongs_to` fields, which do work).
end

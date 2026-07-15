class Avo::Resources::UserRole < Avo::BaseResource
  def fields
    field :id, as: :id
    field :user, as: :belongs_to
    field :role, as: :belongs_to
  end
end

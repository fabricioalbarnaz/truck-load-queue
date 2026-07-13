class Avo::Resources::Role < Avo::BaseResource
  self.icon = "tabler/outline/shield"
  # self.avatar = {
  #   source: :avatar
  # }
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    # field :avatar, as: :avatar
    field :key, as: :text
    field :name, as: :text
  end
end

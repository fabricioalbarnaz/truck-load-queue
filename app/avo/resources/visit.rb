class Avo::Resources::Visit < Avo::BaseResource
  # self.icon = "tabler/outline/users"
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
    field :driver, as: :belongs_to
    field :truck, as: :belongs_to
    field :status, as: :text
    field :entered_yard_at, as: :date_time
    field :order_issued_at, as: :date_time
    field :loading_started_at, as: :date_time
    field :finished_at, as: :date_time
    field :checked_in_by, as: :belongs_to
    field :order_issued_by, as: :belongs_to
    field :finished_by, as: :belongs_to
  end
end

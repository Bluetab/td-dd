defmodule TdDdWeb.Schema.Grants do
  @moduledoc """
  Absinthe schema definitions for Grants
  """

  use Absinthe.Schema.Notation

  alias TdDdWeb.Resolvers

  object :grant_queries do
    @desc "Get grants with specific filters and paginated"
    field :grants, :paginated_grants do
      arg(:first, :integer)
      arg(:last, :integer)
      arg(:after, :cursor)
      arg(:before, :cursor)
      arg(:filters, :grants_filter)
      resolve(&Resolvers.Grants.grants/3)
    end
  end

  object :grant do
    field :id, non_null(:id)
    field :detail, :json
    field :start_date, :date
    field :end_date, :date
    field :user_id, :id
    field :data_structure_id, :id
    field :data_structure, :data_structure
    field :data_structure_version, :data_structure_version
    field :inserted_at, :datetime
    field :updated_at, :datetime
    field :source_user_name, :string
    field :pending_removal, :boolean
    field :external_ref, :string
    field :dsv_children, list_of(:data_structure_version)
  end

  object :paginated_grants do
    field :total_count, :integer
    field :page, non_null(list_of(non_null(:grant)))
    field :page_info, :page_info
  end

  input_object :grants_filter do
    field :ids, list_of(:id)
    field :user_ids, list_of(:id)
    field :data_structure_ids, list_of(:id)
    field :start_date, :date_filter
    field :end_date, :date_filter
    field :inserted_at, :date_filter
    field :updated_at, :date_filter
    field :pending_removal, :boolean
  end
end

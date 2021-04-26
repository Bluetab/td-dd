defmodule TdDd.UserSearchFilters.UserSearchFilter do
  @moduledoc """
  Module for saving user search filters of Concepts
  """

  use Ecto.Schema

  import Ecto.Changeset

  schema "user_search_filters" do
    field(:filters, :map)
    field(:name, :string)
    field(:user_id, :integer)

    timestamps()
  end

  def changeset(user_search_filter, params) do
    user_search_filter
    |> cast(params, [:name, :filters, :user_id])
    |> validate_required([:name, :filters, :user_id])
    |> unique_constraint([:name, :user_id],
      name: :user_search_filters_name_user_id_index,
      message: "duplicated"
    )
  end
end

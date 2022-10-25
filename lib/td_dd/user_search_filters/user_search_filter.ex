defmodule TdDd.UserSearchFilters.UserSearchFilter do
  @moduledoc """
  Module for saving user search filters of Concepts
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDfLib.Validation

  schema "user_search_filters" do
    field(:filters, :map)
    field(:name, :string)
    field(:user_id, :integer)
    field(:scope, :string)
    field(:is_global, :boolean)

    timestamps()
  end

  def changeset(user_search_filter, params) do
    user_search_filter
    |> cast(params, [:name, :filters, :user_id, :scope, :is_global])
    |> validate_required([:name, :filters, :user_id, :scope])
    |> validate_change(:filters, &Validation.validate_safe/2)
    |> validate_inclusion(:scope, ["data_structure", "rule", "rule_implementation"])
    |> unique_constraint([:name, :user_id],
      name: :user_search_filters_name_user_id_index,
      message: "duplicated"
    )
  end
end

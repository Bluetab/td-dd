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
    field(:scope, Ecto.Enum, values: [:data_structure, :rule, :rule_implementation])

    timestamps()
  end

  def scope_to_atom("data_structure"), do: :data_structure
  def scope_to_atom("rule"), do: :rule
  def scope_to_atom("rule_implementation"), do: :rule_implementation
  def scope_to_atom(_), do: nil

  def changeset(user_search_filter, params) do
    user_search_filter
    |> cast(params, [:name, :filters, :user_id, :scope])
    |> validate_required([:name, :filters, :user_id, :scope])
    |> validate_change(:filters, &Validation.validate_safe/2)
    |> unique_constraint([:name, :user_id],
      name: :user_search_filters_name_user_id_index,
      message: "duplicated"
    )
  end
end

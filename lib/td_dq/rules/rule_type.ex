defmodule TdDq.Rules.RuleType do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  alias TdDq.Rules.RuleType

  @available_params_keys ["system_params", "type_params"]

  schema "rule_types" do
    field(:name, :string)
    field(:params, :map)

    timestamps()
  end

  @doc false
  def changeset(%RuleType{} = rule_type, attrs) do
    rule_type
    |> cast(attrs, [:name, :params])
    |> validate_required([:name, :params])
    |> validate_params
    |> unique_constraint(:name)
  end

  defp validate_params(changeset) do
    params = get_change(changeset, :params)

    if params == %{} or params == nil do
      changeset
    else
      params = Map.take(get_change(changeset, :params), @available_params_keys)

      with true <- length(Map.keys(params)) == length(@available_params_keys),
           true <-
             length(Map.keys(get_change(changeset, :params))) == length(@available_params_keys) do
        changeset
      else
        false ->
          changeset
          |> add_error(
            :params,
            "Invalid params. Available params: #{inspect(@available_params_keys)}"
          )
      end
    end
  end
end

defmodule TdDq.Repo.Migrations.AddValueTypeFilterInOperator do
  use Ecto.Migration
  import Ecto.Query, warn: false

  alias Ecto.Adapters.SQL
  alias TdDd.Repo
  alias TdDq.Rules.Implementations.Implementation

  @update_statement """
    UPDATE rule_implementations
    SET validations = $1
    WHERE id = $2
  """

  def change do
    condition =
      dynamic(
        [ri],
        fragment(
          "exists (select * from unnest(?) obj where (obj->'operator'->>'name')::text = ?)",
          ri.validations,
          "references"
        ) or false
      )

    condition =
      dynamic(
        [ri],
        fragment(
          "exists (select * from unnest(?) obj where (obj->'operator'->>'name')::text = ?)",
          ri.validations,
          "not_references"
        ) or ^condition
      )

    from(r in "rule_implementations",
      select: %{id: r.id, validations: r.validations}
    )
    |> where(^condition)
    |> Repo.all()
    |> Enum.map(&add_value_type_filter_to_validations/1)
    |> Enum.each(&execute_update/1)
  end

  defp add_value_type_filter_to_validations(%{validations: validations} = ri) do
    new_validations = Enum.map(validations, &add_value_type_filter/1)
    Map.put(ri, :validations, new_validations)
  end

  defp add_value_type_filter(
         %{"operator" => %{"name" => "references"} = operator} = validation_row
       ) do
    case Map.get(operator, "value_type_filter") do
      nil -> Map.put(validation_row, "operator", Map.put(operator, "value_type_filter", "any"))
      _ -> validation_row
    end
  end

  defp add_value_type_filter(
         %{"operator" => %{"name" => "not_references"} = operator} = validation_row
       ) do
    case Map.get(operator, "value_type_filter") do
      nil -> Map.put(validation_row, "operator", Map.put(operator, "value_type_filter", "any"))
      _ -> validation_row
    end
  end

  defp add_value_type_filter(validation_row) do
    validation_row
  end

  defp execute_update(%{id: id, validations: validations}) do
    SQL.query(Repo, @update_statement, [validations, id])
  end
end

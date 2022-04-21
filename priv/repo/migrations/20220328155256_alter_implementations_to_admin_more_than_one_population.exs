defmodule TdDd.Repo.Migrations.AlterImplementationsToAdminMoreThanOnePopulation do
  use Ecto.Migration

  def change do
    alter table("rule_implementations") do
      add(:populations, {:array, :map}, default: [])
    end

    execute(
      """
        update rule_implementations set populations = array[json_build_object('population', array_to_json(population))]
        where array_length(population, 1) > 0;
      """,
      """
      update rule_implementations ri set population = first_population
      from (
        select id, array_agg(first_population) as first_population
        from rule_implementations
        cross join lateral json_array_elements(populations[1]::json#>'{population}') as first_population
        where array_length(populations, 1) > 0
        GROUP BY id
      ) as t
      where t.id = ri.id
      """
    )

    alter table("rule_implementations") do
      remove(:population, {:array, :map}, default: [])
    end
  end
end

defmodule TdDq.Repo.Migrations.UniqueRuleImplementationKey do
  use Ecto.Migration
  import Ecto.Query

  alias TdDd.Repo

  def change do
    "rule_implementations"
    |> group_by([ri], [ri.implementation_key])
    |> having([ri], count(ri.id) > 1)
    |> select([ri], {ri.implementation_key})
    |> Repo.all()
    |> Enum.map(&do_update(&1))

    drop(unique_index(:rule_implementations, [:implementation_key], where: "deleted_at IS NULL"))

    create(unique_index(:rule_implementations, [:implementation_key]))
  end

  defp do_update({implementation_key}) do
    now = DateTime.utc_now()

    "rule_implementations"
    |> where([ri], ri.implementation_key == ^implementation_key)
    |> where([ri], not is_nil(ri.deleted_at))
    |> update([ri],
      set: [
        updated_at: ^now,
        implementation_key: fragment("? || ' ' || ?", ^implementation_key, ri.deleted_at)
      ]
    )
    |> Repo.update_all([])
  end
end

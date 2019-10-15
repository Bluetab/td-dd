defmodule TdDq.Repo.Migrations.ModifyStatusFieldInRulesTable do
  @moduledoc """
  The goal of the migration would be to modify the type
  to the status column to boolean
  """

  use Ecto.Migration
  import Ecto.Query
  alias TdDq.Repo

  defp parse_status("selectedToExecute"), do: true

  defp parse_status("implemented"), do: true

  defp parse_status(_status), do: false

  defp retrieve_deleted_at("deleted", last_update), do: last_update

  defp retrieve_deleted_at(_, _), do: nil

  defp update_rule_record(%{id: id, status: status, last_update: last_update}) do
    last_update = status |> retrieve_deleted_at(last_update)
    active = status |> parse_status()

    from(r in "rules",
      update: [set: [active: ^active, deleted_at: ^last_update]],
      where: r.id == ^id
    )
    |> Repo.update_all([])
  end

  def up do
    rename(table(:rules), :status, to: :status_backup)
    alter(table(:rules), do: add(:active, :boolean))
    alter(table(:rules), do: add(:deleted_at, :utc_datetime))
    flush()

    from(r in "rules",
      select: %{
        id: r.id,
        status: r.status_backup,
        last_update: r.updated_at
      }
    )
    |> Repo.all()
    |> Enum.each(&update_rule_record/1)
  end

  def down do
    alter(table(:rules), do: remove(:active))
    alter(table(:rules), do: remove(:deleted_at))
    rename(table(:rules), :status_backup, to: :status)
  end
end

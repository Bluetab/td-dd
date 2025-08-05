defmodule TdDd.Lineage.Units.Workers.DeleteUnit do
  @moduledoc """
  Worker to delete a unit
  """

  use Oban.Worker,
    queue: "delete_units",
    max_attempts: 5,
    unique: [
      fields: [:args, :worker],
      keys: [:unit_id],
      states: Oban.Job.states() -- [:cancelled, :discarded, :completed]
    ]

  alias TdDd.Lineage.Units
  alias TdDd.Lineage.Units.Unit

  def perform(%Oban.Job{args: %{"unit_id" => id} = params}) do
    with %Unit{} = unit <- Units.get(id),
         {:ok, _} <- Units.delete_unit(unit, logical: params["logical"] != "false") do
      :ok
    else
      nil -> {:cancel, :not_found}
    end
  end
end

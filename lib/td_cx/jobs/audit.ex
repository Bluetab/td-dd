defmodule TdCx.Jobs.Audit do
  @moduledoc """
  The Jobs Audit context. The public functions in this module are designed to
  be called using `Ecto.Multi.run/5`, although the first argument (`repo`) is
  not currently used.
  """

  import TdCx.Audit.AuditSupport, only: [publish: 5]

  @doc """
  Publishes an `:job_status` event. Should be called using `Ecto.Multi.run/5`.
  """
  def job_status_updated(_repo, %{event: event, source_id: id}, user_id) do
    payload = Map.take(event, [:message, :inserted_at, :job_id, :id])
    publish(String.downcase(event.type), "jobs", id, user_id, payload)
  end
end

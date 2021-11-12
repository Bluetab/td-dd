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
  def job_status_updated(
        _repo,
        %{
          event: event,
          source_id: source_id,
          external_id: external_id,
          source_external_id: source_external_id
        },
        user_id
      ) do
    payload =
      event
      |> Map.take([:message, :inserted_at, :id])
      |> Map.put(:source_id, source_id)
      |> Map.put(:external_id, external_id)
      |> Map.put(:source_external_id, source_external_id)

    publish("job_status_" <> String.downcase(event.type), "jobs", event.job_id, user_id, payload)
  end
end

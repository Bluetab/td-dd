defmodule TdDd.Events.ProfileEvents do
  @moduledoc """
  The Events context.
  """

  alias TdDd.Events.ProfileEvent
  alias TdDd.Repo

  def create_event(attrs \\ %{}) do
    attrs
    |> ProfileEvent.create_changeset()
    |> Repo.insert()
  end

  def complete(execution_ids) do
    inserted_at = DateTime.utc_now()

    events =
      execution_ids
      |> Enum.map(fn id ->
        %{
          profile_execution_id: id,
          type: "SUCCEEDED",
          message: "Profile Uploaded.",
          inserted_at: inserted_at
        }
      end)

    Repo.insert_all(ProfileEvent, events, returning: true)
  end
end

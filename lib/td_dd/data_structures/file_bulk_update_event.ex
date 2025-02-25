defmodule TdDd.DataStructures.FileBulkUpdateEvent do
  @moduledoc "File Bulk Update Event entity"

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDfLib.Validation

  schema "file_bulk_update_events" do
    field(:user_id, :integer)
    field(:response, :map)
    field(:hash, :string)
    field(:task_reference, :string)
    field(:status, :string)
    field(:node, :string)
    field(:message, :string)
    field(:filename, :string)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [
      :user_id,
      :response,
      :hash,
      :task_reference,
      :status,
      :message,
      :filename
    ])
    |> put_node
    |> validate_required([:user_id, :hash, :filename, :status, :node])
    |> validate_change(:response, &Validation.validate_safe/2)
    |> validate_length(:message, max: 1_000)
  end

  defp put_node(changeset) do
    cast(changeset, %{node: Atom.to_string(Node.self())}, [:node])
  end
end

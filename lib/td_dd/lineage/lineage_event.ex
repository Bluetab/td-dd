defmodule TdDd.Lineage.LineageEvent do
  @moduledoc "Event entity"

  use Ecto.Schema

  import Ecto.Changeset


  schema "lineage_events" do
    field(:user_id, :integer)
    field(:graph_data, :string)
    field(:graph_hash, :string)
    field(:task_reference, :string)
    field(:status, :string)
    field(:node, :string)
    field(:message, :string)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:user_id, :graph_data, :graph_hash, :task_reference, :status, :message])
    |> put_node
    |> validate_required([:user_id, :graph_data, :graph_hash, :task_reference, :status, :node])
    |> validate_length(:graph_data, max: 255)
    |> validate_length(:message, max: 1_000)
  end

  def create_changeset(%{} = params) do
    %__MODULE__{}
    |> cast(params, [:user_id, :graph_hash, :task_reference, :type, :message])
    |> put_node
    |> validate_required([:user_id, :graph_data, :graph_hash, :task_reference, :status, :node])
    |> validate_length(:graph_data, max: 255)
    |> validate_length(:message, max: 1_000)
  end

  defp put_node(changeset) do
    cast(changeset, %{node: Atom.to_string(Node.self())}, [:node])
  end
end

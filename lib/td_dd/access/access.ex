defmodule TdDd.Access do
  @moduledoc """
  Ecto Schema module for Access
  """
  use Ecto.Schema
  @foreign_key_type :string

  import Ecto.Changeset
  alias TdCache.UserCache
  alias TdDd.DataStructures.DataStructure

  schema "accesses" do
    belongs_to(:data_structure, DataStructure,
      foreign_key: :data_structure_external_id,
      type: :string,
      references: :external_id
    )

    field(:source_user_name, :string)
    field(:user_name, :string)
    field(:user_external_id, :string)
    field(:user_id, :integer)
    field(:details, :map)
    field(:accessed_at, :utc_datetime)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = access, %{} = params) do
    access
    |> cast(params, [
      :data_structure_external_id,
      :user_name,
      :user_external_id,
      :source_user_name,
      :details,
      :accessed_at,
      :inserted_at
    ])
    |> maybe_put_user_id_by_name(params)
    |> maybe_put_user_id_by_external_id(params)
    |> validate_required([:data_structure_external_id, :source_user_name, :accessed_at])
    |> foreign_key_constraint(:data_structure_external_id)
  end

  defp maybe_put_user_id_by_name(changeset, %{} = params) do
    with nil <- fetch_field!(changeset, :user_id),
         {:ok, user_name} <- fetch_change(changeset, :user_name),
         {:ok, %{id: user_id}} <- UserCache.get_by_user_name(user_name) do
      put_change(changeset, :user_id, user_id)
    else
      user_id when is_integer(user_id) -> changeset
      _ -> cast(changeset, params, [:user_id])
    end
  end

  defp maybe_put_user_id_by_external_id(changeset, %{} = params) do
    with nil <- fetch_field!(changeset, :user_id),
         {:ok, user_external_id} <- fetch_change(changeset, :user_external_id),
         {:ok, %{id: user_id}} <- UserCache.get_by_external_id(user_external_id) do
      put_change(changeset, :user_id, user_id)
    else
      user_id when is_integer(user_id) -> changeset
      _ -> cast(changeset, params, [:user_id])
    end
  end
end

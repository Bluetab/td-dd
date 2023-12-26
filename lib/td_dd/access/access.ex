defmodule TdDd.Access do
  @moduledoc """
  Ecto Schema module for Access
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias TdCache.UserCache
  alias TdDd.DataStructures.DataStructure
  alias TdDfLib.Validation

  @foreign_key_type :string

  schema "accesses" do
    belongs_to(:data_structure, DataStructure,
      foreign_key: :data_structure_external_id,
      type: :string,
      references: :external_id
    )

    field(:source_user_name, :string)
    field(:user_id, :integer)
    field(:details, :map)
    field(:accessed_at, :utc_datetime)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = access, %{} = params) do
    access
    |> cast(params, [
      :data_structure_external_id,
      :source_user_name,
      :details,
      :accessed_at,
      :inserted_at,
      :updated_at
    ])
    |> validate_user_id(params)
    |> validate_required([:data_structure_external_id, :source_user_name, :accessed_at])
    |> validate_change(:details, &Validation.validate_safe/2)
    |> foreign_key_constraint(:data_structure_external_id)
  end

  defp validate_user_id(changeset, %{} = params) do
    case get_user_id(params) do
      {:ok, user_id} ->
        put_change(changeset, :user_id, user_id)

      _ ->
        changeset
    end
  end

  defp get_user_id(%{"user_id" => user_id}) do
    case UserCache.get(user_id) do
      {:ok, %{id: user_id}} -> {:ok, user_id}
      _ -> nil
    end
  end

  defp get_user_id(%{"user_name" => user_name}) do
    case UserCache.get_by_user_name(user_name) do
      {:ok, %{id: user_id}} -> {:ok, user_id}
      _ -> nil
    end
  end

  defp get_user_id(%{"user_external_id" => user_external_id}) do
    case UserCache.get_by_external_id(user_external_id) do
      {:ok, %{id: user_id}} -> {:ok, user_id}
      _ -> nil
    end
  end

  defp get_user_id(_), do: nil
end

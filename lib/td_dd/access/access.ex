defmodule TdDd.Access do

  use Ecto.Schema
  @foreign_key_type :string

  import Ecto.Changeset
  alias TdDd.DataStructures.DataStructure
  alias TdCache.UserCache
  alias TdDd.Repo

  schema "accesses" do
    belongs_to(:data_structure, DataStructure, foreign_key: :data_structure_external_id, type: :string, references: :external_id)
    field(:source_user_name, :string)
    field(:user_name, :string)
    field(:user_external_id, :string)
    field(:user_id, :integer)
    field(:details, :map)
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = access, %{} = params) do
    access
    |> cast(params, [:data_structure_external_id, :user_name, :user_external_id, :source_user_name, :details])
    |> IO.inspect(label: "CAST")
    |> maybe_put_user_id_by_name(params)
    |> maybe_put_user_id_by_external_id(params)
    |> validate_required([:data_structure_external_id, :source_user_name])
    #|> validate_ds_external_id()
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
    with nil <- fetch_field!(changeset, :user_id) |> IO.inspect(label: "FETCH_FIELD"),
         {:ok, user_external_id} <- fetch_change(changeset, :user_external_id) |> IO.inspect(label: "EXTERNAL_ID"),
         {:ok, %{id: user_id}} <- UserCache.get_by_external_id(user_external_id) |> IO.inspect(label: "GET_BY_EXTERNAL_ID") do
      put_change(changeset, :user_id, user_id)
    else
      user_id when is_integer(user_id) -> changeset
      _ -> cast(changeset, params, [:user_id])
    end
  end

  # defp validate_ds_external_id(changeset) do
  #   ds_external_id = get_change(changeset, :data_structure_external_id)

  #   (from ds in DataStructure, where: ds.external.id == ds_external_id)
  #   |> case Repo.exists?() do
  #     changeset
  #   else
  #     add_error(changeset, :data_structure_external_id, "non")


  #   end

  #   case valid_value?(value, changeset, params) do
  #     {:ok, changeset} -> valid_range?(value, changeset, params)
  #     {:invalid_value, changeset} -> changeset
  #   end
  # end




end

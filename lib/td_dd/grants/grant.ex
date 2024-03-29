defmodule TdDd.Grants.Grant do
  @moduledoc """
  Ecto Schema module for Grants.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias TdCache.UserCache
  alias TdDd.DataStructures.DataStructure
  alias TdDfLib.Validation

  schema "grants" do
    field(:detail, :map)
    field(:end_date, :date)
    field(:start_date, :date)
    field(:source_user_name, :string)
    field(:user_id, :integer)
    field(:pending_removal, :boolean, default: false)
    field(:user_name, :string, virtual: true)
    field(:user_external_id, :string, virtual: true)
    field(:user, :map, virtual: true)
    field(:resource, :map, virtual: true, default: %{})
    field(:domain_ids, {:array, :integer}, virtual: true, default: [])
    field(:external_ref, :string)

    belongs_to(:data_structure, DataStructure)
    has_one(:system, through: [:data_structure, :system])
    has_one(:data_structure_version, through: [:data_structure, :current_version])

    timestamps(type: :utc_datetime_usec)
  end

  def create_changeset(params, is_bulk \\ false)

  def create_changeset(%{} = params, is_bulk) do
    create_changeset(%__MODULE__{}, params, is_bulk)
  end

  def create_changeset(%__MODULE__{} = struct, %{} = params, false = _is_bulk) do
    struct
    |> common_changeset(params)
    |> validate_required(:user_id)
  end

  def create_changeset(%__MODULE__{} = struct, %{} = params, true = _is_bulk) do
    struct
    |> common_changeset(params)
  end

  def update_changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> common_changeset(params)
  end

  def common_changeset(struct_or_changeset, %{} = params) do
    struct_or_changeset
    |> cast(params, [
      :detail,
      :start_date,
      :end_date,
      :user_name,
      :user_external_id,
      :pending_removal,
      :source_user_name,
      :external_ref
    ])
    |> check_user_params(params)
    |> maybe_put_user_id(params)
    |> validate_required([:start_date, :data_structure_id, :source_user_name])
    |> validate_change(:user_id, &validate_user_id/2)
    |> validate_change(:detail, &Validation.validate_safe/2)
    |> foreign_key_constraint(:data_structure_id)
    |> check_constraint(:end_date, name: :date_range)
    |> exclusion_constraint(:source_user_name, name: :no_overlap_source_user_name)
  end

  def check_user_params(
        changeset,
        %{"user_name" => _user_name, "user_external_id" => _user_external_id}
      ) do
    add_error(changeset, :user_name_user_external_id, "use either user_name or user_external_id")
  end

  def check_user_params(
        changeset,
        %{"user_id" => _user_id} = params
      )
      when is_map_key(params, "user_name") or is_map_key(params, "user_external_id") do
    add_error(changeset, :user_id, "use either user_id or one of user_name, user_external_id")
  end

  def check_user_params(changeset, _params) do
    changeset
  end

  defp maybe_put_user_id(
         %Ecto.Changeset{data: %__MODULE__{user_id: user_id}} = changeset,
         %{} = _params
       )
       when is_integer(user_id) do
    validate_change(changeset, :user_id, &validate_user_id/2)
  end

  defp maybe_put_user_id(
         %Ecto.Changeset{data: %__MODULE__{user_id: nil}, changes: changes} = changeset,
         %{} = params
       ) do
    case get_user_id(changes) do
      {:ok, %{id: user_id}} ->
        put_change(changeset, :user_id, user_id)

      {:ok, nil} ->
        cast(changeset, params, [:user_id]) |> validate_change(:user_id, &validate_user_id/2)
    end
  end

  defp get_user_id(%{user_name: user_name}) do
    UserCache.get_by_user_name(user_name)
  end

  defp get_user_id(%{user_external_id: user_external_id}) do
    UserCache.get_by_external_id(user_external_id)
  end

  defp get_user_id(_params) do
    {:ok, nil}
  end

  defp validate_user_id(:user_id, user_id) do
    if UserCache.exists?(user_id) do
      []
    else
      [user_id: "does not exist"]
    end
  end

  def put_data_structure(changeset, data_structure) do
    put_assoc(changeset, :data_structure, data_structure)
  end
end

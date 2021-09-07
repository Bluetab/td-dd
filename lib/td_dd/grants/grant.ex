defmodule TdDd.Grants.Grant do
  @moduledoc """
  Ecto Schema module for Grants.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias TdDd.Grants.Grant
  alias TdCache.UserCache
  alias TdDd.DataStructures.DataStructure
  alias TdDq.Search.Helpers

  schema "grants" do
    field(:detail, :map)
    field(:end_date, :date)
    field(:start_date, :date)
    field(:user_id, :integer)
    field(:user_name, :string, virtual: true)
    field(:user, :map, virtual: true)
    field(:resource, :map, virtual: true, default: %{})
    field(:domain_ids, {:array, :integer}, virtual: true, default: [])

    belongs_to(:data_structure, DataStructure)
    has_one(:system, through: [:data_structure, :system])
    has_one(:data_structure_version, through: [:data_structure, :current_version])

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:detail, :start_date, :end_date, :user_name])
    |> maybe_put_user_id(params)
    |> validate_required([:start_date, :user_id, :data_structure_id])
    |> validate_change(:user_id, &validate_user_id/2)
    |> foreign_key_constraint(:data_structure_id)
    |> check_constraint(:end_date, name: :date_range)
    |> exclusion_constraint(:user_id, name: :no_overlap)
  end

  defp maybe_put_user_id(changeset, %{} = params) do
    with nil <- fetch_field!(changeset, :user_id),
         {:ok, user_name} <- fetch_change(changeset, :user_name),
         {:ok, %{id: user_id}} <- UserCache.get_by_user_name(user_name) do
      put_change(changeset, :user_id, user_id)
    else
      user_id when is_integer(user_id) -> changeset
      _ -> cast(changeset, params, [:user_id])
    end
  end

  defp validate_user_id(:user_id, user_id) do
    if UserCache.exists?(user_id) do
      []
    else
      [user_id: "does not exist"]
    end
  end

  defimpl Elasticsearch.Document do
    @impl Elasticsearch.Document
    def id(%Grant{id: id}), do: id

    @impl Elasticsearch.Document
    def routing(_), do: false

    @impl Elasticsearch.Document
    def encode(%Grant{} = grant) do
      dsv = Elasticsearch.Document.encode(grant.data_structure_version)
      domain = Helpers.get_domain(grant.data_structure_version.data_structure)
      domain_ids = Helpers.get_domain_ids(domain)
      domain_parents = Helpers.get_domain_parents(domain)

      %{
        id: grant.id,
        detail: grant.detail,
        start_date: grant.start_date,
        end_date: grant.end_date,
        user_id: grant.user_id,
        user: Helpers.get_user(grant.user_id),
        data_structure_version:
        dsv
        |> Map.put(:domain, domain)
        |> Map.put(:domain_ids, domain_ids)
        |> Map.put(:domain_parents, domain_parents)
      }

    end
  end

  def put_data_structure(changeset, data_structure) do
    put_assoc(changeset, :data_structure, data_structure)
  end
end

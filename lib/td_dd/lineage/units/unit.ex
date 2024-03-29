defmodule TdDd.Lineage.Units.Unit do
  @moduledoc """
  Ecto schema module for graph nodes.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias TdCache.DomainCache
  alias TdDd.Lineage.Units.Edge
  alias TdDd.Lineage.Units.Event
  alias TdDd.Lineage.Units.Node

  schema "units" do
    field(:name, :string)
    field(:deleted_at, :utc_datetime_usec)
    field(:domain_id, :integer)
    field(:status, :map, virtual: true)

    has_many(:edges, Edge)
    has_many(:events, Event)

    many_to_many(:nodes, Node, join_through: "units_nodes")

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = collection, %{} = params) do
    collection
    |> cast(params, [:name, :deleted_at, :domain_id, :updated_at])
    |> validate_required(:name)
    |> put_domain_id()
    |> unset_deleted_at()
    |> unique_constraint(:name)
  end

  defp unset_deleted_at(changeset) do
    case fetch_change(changeset, :deleted_at) do
      {:ok, _} -> changeset
      :error -> put_change(changeset, :deleted_at, nil)
    end
  end

  defp put_domain_id(%{params: %{"domain" => nil}} = changeset) do
    put_change(changeset, :domain_id, nil)
  end

  defp put_domain_id(%{params: %{"domain" => external_id}} = changeset)
       when is_binary(external_id) do
    case DomainCache.external_id_to_id(external_id) do
      {:ok, domain_id} -> put_change(changeset, :domain_id, domain_id)
      :error -> add_error(changeset, :domain_id, "domain not found")
    end
  end

  defp put_domain_id(%{} = changeset), do: changeset
end

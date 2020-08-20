defmodule TdDd.Factory do
  @moduledoc false
  use ExMachina.Ecto, repo: TdDd.Repo
  use TdDfLib.TemplateFactory

  alias TdDd.Accounts.User
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureRelation
  alias TdDd.DataStructures.DataStructureType
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.Profile
  alias TdDd.DataStructures.RelationType
  alias TdDd.DataStructures.StructureMetadata
  alias TdDd.Lineage.Units
  alias TdDd.Systems.System
  alias TdDd.UserSearchFilters.UserSearchFilter

  def user_factory do
    %User{
      id: sequence(:user_id, & &1),
      user_name: sequence("user_name"),
      # TODO: Revise all usages of build(:user), etc.
      is_admin: true
    }
  end

  def data_structure_factory(attrs) do
    attrs = default_assoc(attrs, :system_id, :system)

    %DataStructure{
      confidential: false,
      external_id: sequence("ds_external_id"),
      last_change_by: 0
    }
    |> merge_attributes(attrs)
  end

  def data_structure_version_factory(attrs) do
    attrs = default_assoc(attrs, :data_structure_id, :data_structure)

    %DataStructureVersion{
      description: "some description",
      group: "some group",
      name: "some name",
      metadata: %{"description" => "some description"},
      version: 0,
      type: "Table"
    }
    |> merge_attributes(attrs)
  end

  def data_structure_relation_factory do
    %DataStructureRelation{}
  end

  def data_structure_type_factory do
    %DataStructureType{
      id: sequence(:structure_type_id, &(&1 + 999_000)),
      structure_type: "Table",
      template_id: 0,
      translation: ""
    }
  end

  def system_factory do
    %System{
      name: sequence("system_name"),
      external_id: sequence("system_external_id")
    }
  end

  def relation_type_factory do
    %RelationType{
      name: "relation_type_name"
    }
  end

  def profile_factory(attrs) do
    attrs = default_assoc(attrs, :data_structure_id, :data_structure)

    %Profile{value: %{"foo" => "bar"}}
    |> merge_attributes(attrs)
  end

  def structure_metadata_factory do
    %StructureMetadata{
      fields: %{"foo" => "bar"},
      version: 0
    }
  end

  def unit_factory do
    %Units.Unit{name: sequence("unit")}
  end

  def unit_event_factory do
    %Units.Event{event: "EventType", inserted_at: DateTime.utc_now()}
  end

  def node_factory do
    %Units.Node{external_id: sequence("node_external_id"), type: "Resource"}
  end

  def edge_factory do
    %Units.Edge{type: "DEPENDS"}
  end

  def user_search_filter_factory do
    %UserSearchFilter{
      id: sequence(:user_search_filter, & &1),
      name:  sequence("filter_name"),
      filters: %{country: ["Sp"]},
      user_id: sequence(:user_id, & &1)
    }
  end

  defp default_assoc(attrs, id_key, key) do
    if Enum.any?([key, id_key], &Map.has_key?(attrs, &1)) do
      attrs
    else
      Map.put(attrs, key, build(key))
    end
  end
end

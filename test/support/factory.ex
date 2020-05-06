defmodule TdDd.Factory do
  @moduledoc false
  use ExMachina.Ecto, repo: TdDd.Repo

  alias TdDd.Accounts.User
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureRelation
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.Profile
  alias TdDd.DataStructures.RelationType
  alias TdDd.DataStructures.StructureMetadata
  alias TdDd.Lineage.Units
  alias TdDd.Systems.System

  def user_factory do
    %User{
      id: 0,
      user_name: "bufoncillo",
      is_admin: false
    }
  end

  def data_structure_factory do
    external_id = "external_id #{random_id()}"

    %DataStructure{
      last_change_by: 0,
      system_id: 1,
      versions: [],
      confidential: false,
      external_id: external_id
    }
  end

  def data_structure_version_factory do
    %DataStructureVersion{
      deleted_at: nil,
      description: "some description",
      group: "some group",
      name: "some name",
      metadata: %{"description" => "some description"},
      version: 0,
      type: "Table"
    }
  end

  def data_structure_version_no_table_factory do
    %DataStructureVersion{
      deleted_at: nil,
      description: "some description",
      group: "some group",
      name: "some name",
      metadata: %{"description" => "some description"},
      version: 0,
      type: "Schema"
    }
  end

  def data_structure_relation_factory do
    %DataStructureRelation{}
  end

  def system_factory do
    %System{
      name: "My system",
      external_id: "System_ref"
    }
  end

  def relation_type_factory do
    %RelationType{
      name: "relation_type_name"
    }
  end

  def profile_factory do
    %Profile{
      value: %{"foo" => "bar"},
      data_structure: build(:data_structure)
    }
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

  defp random_id, do: :rand.uniform(100_000_000)
end

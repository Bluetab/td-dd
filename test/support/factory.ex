defmodule TdDd.Factory do
  @moduledoc false
  use ExMachina.Ecto, repo: TdDd.Repo
  use TdDfLib.TemplateFactory

  alias TdCx.Configurations.Configuration
  alias TdCx.Events.Event
  alias TdCx.Jobs.Job
  alias TdCx.Sources.Source

  alias TdDd.Auth.Claims
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

  def claims_factory(attrs) do
    %Claims{
      user_id: sequence(:user_id, & &1),
      user_name: sequence("user_name"),
      role: "admin",
      jti: sequence("jti")
    }
    |> merge_attributes(attrs)
  end

  def cx_claims_factory(attrs) do
    %TdCx.Auth.Claims{
      user_id: sequence(:user_id, & &1),
      user_name: sequence("user_name"),
      role: "admin",
      jti: sequence("jti")
    }
    |> merge_attributes(attrs)
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
      structure_type: sequence("structure_type"),
      template_id: sequence(:template_id, & &1),
      translation: sequence("system_name"),
      metadata_fields: %{"foo" => "bar"}
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
      name: sequence("filter_name"),
      filters: %{country: ["Sp"]},
      user_id: sequence(:user_id, & &1)
    }
  end

  def domain_factory do
    %{
      name: sequence("domain_name"),
      id: sequence(:domain_id, &(&1 + 1000)),
      external_id: sequence("domain_external_id"),
      updated_at: DateTime.utc_now()
    }
  end

  def source_factory do
    %Source{
      config: %{},
      external_id: sequence("source_external_id"),
      secrets_key: sequence("source_secrets_key"),
      type: sequence("source_type")
    }
  end

  def job_factory do
    %Job{
      source: build(:source),
      type: sequence(:job_type, ["Metadata", "DQ", "Profile"])
    }
  end

  def event_factory do
    %Event{
      job: build(:job),
      type: sequence("event_type"),
      message: sequence("event_message")
    }
  end

  def configuration_factory do
    %Configuration{
      type: "config",
      content: %{},
      external_id: sequence("external_id")
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

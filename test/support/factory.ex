defmodule TdDd.Factory do
  @moduledoc false
  use ExMachina.Ecto, repo: TdDd.Repo
  alias TdDd.Accounts.User
  alias TdDd.DataStructures.DataField
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureRelation
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Systems.System

  def user_factory do
    %User{
      id: 0,
      user_name: "bufoncillo",
      is_admin: false
    }
  end

  def data_structure_factory do
    %DataStructure{
      description: "some description",
      group: "some group",
      last_change_at: DateTime.truncate(DateTime.utc_now(), :second),
      last_change_by: 0,
      name: "some name",
      system_id: 1,
      metadata: %{"description" => "some description"},
      ou: "My organization",
      versions: [],
      confidential: false,
      external_id: nil,
      deleted_at: nil
    }
  end

  def data_structure_version_factory do
    %DataStructureVersion{
      version: 0
    }
  end

  def data_structure_relation_factory do
    %DataStructureRelation{}
  end

  def data_field_factory do
    %DataField{
      description: "some description",
      last_change_at: DateTime.truncate(DateTime.utc_now(), :second),
      last_change_by: 0,
      name: "some name",
      nullable: "false",
      precision: "some precision",
      type: "some type",
      metadata: %{}
    }
  end

  def system_factory do
    %System{
      name: "My system",
      external_id: "System_ref"
    }
  end
end

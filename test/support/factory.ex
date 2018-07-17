defmodule TdDd.Factory do
  @moduledoc false
  use ExMachina.Ecto, repo: TdDd.Repo
  alias TdDd.Accounts.User
  alias TdDd.DataStructures.DataField
  alias TdDd.DataStructures.DataStructure

  def user_factory do
    %User {
      id: 0,
      user_name: "bufoncillo",
      is_admin: false
    }
  end

  def data_structure_factory do
    %DataStructure {
      id: 0,
      description: "some description",
      group: "some group",
      last_change_at: DateTime.utc_now(),
      last_change_by: 0,
      name: "some name",
      system: "some system",
      metadata: %{"description" => "some description"},
      ou: "My organization",
      data_fields: []
    }
  end

  def data_field_factory do
    %DataField {
      id: 0,
      business_concept_id: nil,
      description: "some description",
      last_change_at: DateTime.utc_now(),
      last_change_by: 0,
      name: "some name",
      nullable: "false",
      precision: "some precision",
      type: "some type",
      data_structure_id: 0,
      metadata: %{"description" => "some description"}
    }
  end

end

defmodule DataDictionary.Factory do
  @moduledoc false
  use ExMachina.Ecto, repo: DataDictionary.Repo
  alias DataDictionary.Accounts.User
  alias DataDictionary.DataStructures.DataStructure
  alias DataDictionary.DataStructures.DataField

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
      last_change: DateTime.utc_now(),
      modifier: 0,
      name: "some name",
      system: "some system",
    }
  end

  def data_field_factory do
    %DataField {
      id: 0,
      business_concept_id: nil,
      description: "some description",
      last_change: DateTime.utc_now(),
      modifier: 0,
      name: "some name",
      nullable: "false",
      precision: 0,
      type: "some type",
      data_structure_id: 0
    }
  end

end

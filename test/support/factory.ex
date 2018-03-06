defmodule TdDD.Factory do
  @moduledoc false
  use ExMachina.Ecto, repo: TdDD.Repo
  alias TdDD.Accounts.User
  alias TdDD.DataStructures.DataStructure
  alias TdDD.DataStructures.DataField

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
      precision: 0,
      type: "some type",
      data_structure_id: 0
    }
  end

end

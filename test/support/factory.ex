defmodule DataDictionary.Factory do
  @moduledoc false
  use ExMachina.Ecto, repo: DataDictionary.Repo

  def user_factory do
    %DataDictionary.Accounts.User {
      id: 0,
      user_name: "bufoncillo",
      is_admin: false
    }
  end
end

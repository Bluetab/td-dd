defmodule TdDdWeb.DataStructureView do
  use TdDdWeb, :view
  alias TdDdWeb.DataStructureView
  alias TdDd.Accounts.User

  def render("index.json", %{data_structures: data_structures, users: users}) do
    %{data: render_many(data_structures, DataStructureView, "data_structure.json", %{users: users})}
  end

  def render("show.json", %{data_structure: data_structure, users: users}) do
    %{data: render_one(data_structure, DataStructureView, "data_structure.json", %{users: users})}
  end

  def render("data_structure.json", %{data_structure: data_structure, users: users}) do
    %{id: data_structure.id,
      system: data_structure.system,
      group: data_structure.group,
      name: data_structure.name,
      description: data_structure.description,
      type: data_structure.type,
      ou: data_structure.ou,
      lopd: data_structure.lopd,
      last_change_at: data_structure.last_change_at,
      last_change_by: get_last_change_by(data_structure, users),
      inserted_at: data_structure.inserted_at}
  end

  defp get_last_change_by(data_structure, users) do
    default_username = Integer.to_string(data_structure.last_change_by)
    default_user = %User{user_name: default_username}
    last_change_by_id = data_structure.last_change_by
    Enum.find(users, default_user, &(&1.id == last_change_by_id)).user_name
  end

end

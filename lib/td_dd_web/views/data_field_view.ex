defmodule TdDdWeb.DataFieldView do
  use TdDdWeb, :view
  alias TdDd.Accounts.User
  alias TdDd.Utils.CollectionUtils
  alias TdDdWeb.DataFieldView

  def render("index.json", %{data_fields: data_fields, users: users}) do
    %{data: render_many(data_fields, DataFieldView, "data_field.json", %{users: users})}
  end

  def render("show.json", %{data_field: data_field, users: users}) do
    %{data: render_one(data_field, DataFieldView, "data_field.json", %{users: users})}
  end

  def render("data_field.json", %{data_field: data_field, users: users}) do
    %{id: data_field.id,
      name: data_field.name,
      type: data_field.type,
      precision: data_field.precision,
      nullable: data_field.nullable,
      description: data_field.description,
      business_concept_id: data_field.business_concept_id,
      data_structure_id: data_field.data_structure_id,
      last_change_at: data_field.last_change_at,
      last_change_by: get_last_change_by(data_field, users),
      inserted_at: data_field.inserted_at,
      metadata: data_field.metadata,
      external_id: data_field.external_id
    }
  end

  defp get_last_change_by(data_field, users) do
    default_username = Integer.to_string(data_field.last_change_by)
    default_user = %User{user_name: default_username}
    last_change_by_id = data_field.last_change_by
    Enum.find(users, default_user, &(&1.id == last_change_by_id)).user_name
  end

end

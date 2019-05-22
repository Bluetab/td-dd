defmodule TdDqWeb.SearchControllerTest do
  use TdDqWeb.ConnCase

  alias TdDq.Rules
  alias TdPerms.MockDynamicFormCache
  import TdDq.Factory

  setup_all do
    start_supervised(MockDynamicFormCache)
    :ok
  end

  @create_attrs %{
    description: "some description",
    goal: 42,
    minimum: 42,
    name: "some name",
    population: "some population",
    priority: "some priority",
    weight: 42,
    type_params: %{},
    df_content: %{},
    df_name: "none"
  }

  @admin_user_name "app-admin"

  defp create_rule do
    rule_type = insert(:rule_type)

    creation_attrs =
      @create_attrs
      |> Map.put(:rule_type_id, rule_type.id)

    {:ok, rule} = Rules.create_rule(rule_type, creation_attrs)
    rule
  end

  describe "index" do
    @tag authenticated_user: @admin_user_name
    test "search empty rules", %{conn: conn} do
      conn = post(conn, search_path(conn, :search))
      assert json_response(conn, 200)["data"] == []
    end

    @tag authenticated_user: @admin_user_name
    test "search non empty rules", %{conn: conn} do
      create_rule()
      conn = post(conn, search_path(conn, :search))
      assert length(json_response(conn, 200)["data"]) == 1
    end
  end

end

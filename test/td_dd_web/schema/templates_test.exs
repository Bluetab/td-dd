defmodule TdDdWeb.Schema.TemplatesTest do
  use TdDdWeb.ConnCase

  @templates """
  query Templates($scope: String!) {
    templates(scope: $scope) {
      id
      name
      label
      scope
      content
    }
  }
  """

  defp create_template(%{scope: scope}) when is_binary(scope) do
    [
      template: CacheHelpers.insert_template(%{scope: scope})
    ]
  end

  defp create_template(_) do
    [template: CacheHelpers.insert_template()]
  end

  describe "templates query" do
    setup :create_template

    @tag authentication: [role: "user"]
    @tag scope: "qe"
    test "returns data when queried by user", %{
      conn: conn,
      template: %{content: content}
    } do
      assert %{"data" => data} =
              response =
              conn
              |> post("/api/v2", %{
                "query" => @templates,
                "variables" => %{"scope" => "qe"}
              })
              |> json_response(:ok)

      assert response["errors"] == nil
      assert %{"templates" => [template]} = data
      assert %{"content" => ^content} = template
    end
  end
end

defmodule TdDdWeb.ClassifierControllerTest do
  use TdDdWeb.ConnCase

  import Mox

  alias TdCore.Search.IndexWorkerMock

  setup do
    system = insert(:system)

    stub(MockClusterHandler, :call, fn :ai, TdAi.Indices, :exists_enabled?, [] ->
      {:ok, true}
    end)

    IndexWorkerMock.clear()

    [system: system]
  end

  describe "GET /api/systems/:system_id/classifiers" do
    setup :create_classifier

    @tag authentication: [role: "user"]
    test "user can list system classifiers", %{
      conn: conn,
      system: system,
      classifier: %{id: id, name: name}
    } do
      assert %{"data" => [classifier]} =
               conn
               |> get(Routes.system_classifier_path(conn, :index, system))
               |> json_response(:ok)

      assert %{"id" => ^id, "name" => ^name, "filters" => [_filter], "rules" => [_rules]} =
               classifier
    end
  end

  describe "POST /api/systems/:system_id/classifiers" do
    @tag authentication: [role: "admin"]
    test "renders classifier when data is valid", %{
      conn: conn,
      system: system
    } do
      params =
        string_params_for(:classifier,
          filters: [build(:values_filter, classifier: nil)],
          rules: [build(:regex_rule, classifier: nil)]
        )

      assert %{"data" => classifier} =
               conn
               |> post(Routes.system_classifier_path(conn, :create, system), classifier: params)
               |> json_response(:created)

      assert %{"id" => _, "name" => _, "filters" => [_], "rules" => [_]} = classifier
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{conn: conn, system: system} do
      params = %{}

      assert %{"errors" => _errors} =
               conn
               |> post(Routes.system_classifier_path(conn, :create, system), classifier: params)
               |> json_response(:unprocessable_entity)
    end

    @tag authentication: [role: "user"]
    test "needs admin privileges", %{conn: conn, system: system} do
      assert %{"errors" => _errors} =
               conn
               |> post(Routes.system_classifier_path(conn, :create, system), classifier: %{})
               |> json_response(:forbidden)
    end
  end

  describe "DELETE /api/systems/:system_id/classifiers/:id" do
    setup :create_classifier

    @tag authentication: [role: "admin"]
    test "deletes the classifier", %{conn: conn, system: system, classifier: classifier} do
      assert conn
             |> delete(Routes.system_classifier_path(conn, :delete, system, classifier))
             |> response(:no_content)
    end

    @tag authentication: [role: "user"]
    test "needs admin privileges", %{conn: conn, system: system, classifier: classifier} do
      assert conn
             |> delete(Routes.system_classifier_path(conn, :delete, system, classifier))
             |> response(:forbidden)
    end
  end

  defp create_classifier(%{system: system}) do
    classifier =
      insert(:classifier,
        system: system,
        filters: [build(:values_filter, classifier: nil)],
        rules: [build(:regex_rule, classifier: nil)]
      )

    [classifier: classifier]
  end
end

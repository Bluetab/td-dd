defmodule TdDdWeb.ProfileExecutionControllerTest do
  use TdDdWeb.ConnCase

  @moduletag sandbox: :shared

  setup_all do
    domain = CacheHelpers.insert_domain()

    [domain: domain]
  end

  setup tags do
    domain_id =
      case tags do
        %{domain: %{id: id}} -> id
        _ -> nil
      end

    group = insert(:profile_execution_group)
    event = build(:profile_event)

    executions =
      Enum.map(1..5, fn _ ->
        data_structure = insert(:data_structure, domain_ids: [domain_id])

        insert(:profile_execution,
          profile_group: group,
          data_structure: data_structure,
          profile_events: [event],
          profile: build(:profile, data_structure: data_structure)
        )
      end)

    case tags do
      %{permissions: permissions, claims: claims, domain: %{id: domain_id}} ->
        CacheHelpers.put_session_permissions(claims, domain_id, permissions)

      _ ->
        :ok
    end

    [group: group, executions: executions]
  end

  describe "GET /api/profile_executions" do
    @tag authentication: [role: "service"]
    test "returns an OK response with the list of executions", %{
      conn: conn
    } do
      assert %{"data" => executions} =
               conn
               |> get(Routes.profile_execution_path(conn, :index))
               |> json_response(:ok)

      assert length(executions) == 5
    end
  end

  describe "GET /api/profile_executions/:id" do
    @tag authentication: [role: "admin"]
    test "returns an OK response execution data", %{
      conn: conn,
      executions: [execution | _]
    } do
      %{
        id: id,
        data_structure: %{id: structure_id, external_id: external_id},
        profile_events: [%{id: event_id, message: message, type: type}]
      } = execution

      assert %{
               "data" => %{
                 "id" => ^id,
                 "_embedded" => %{
                   "data_structure" => %{"external_id" => ^external_id, "id" => ^structure_id},
                   "profile_events" => [
                     %{
                       "id" => ^event_id,
                       "message" => ^message,
                       "profile_execution_id" => ^id,
                       "type" => ^type
                     }
                   ]
                 }
               }
             } =
               conn
               |> get(Routes.profile_execution_path(conn, :show, id))
               |> json_response(:ok)
    end

    @tag authentication: [user_name: "not_an_admin"]
    @tag permissions: [:view_data_structure, :view_data_structures_profile]
    test "returns an OK response execution data when user has permissions", %{
      conn: conn,
      executions: [execution | _]
    } do
      %{
        id: id,
        data_structure: %{id: structure_id, external_id: external_id},
        profile_events: [%{id: event_id, message: message, type: type}]
      } = execution

      assert %{
               "data" => %{
                 "id" => ^id,
                 "_embedded" => %{
                   "data_structure" => %{"external_id" => ^external_id, "id" => ^structure_id},
                   "profile_events" => [
                     %{
                       "id" => ^event_id,
                       "message" => ^message,
                       "profile_execution_id" => ^id,
                       "type" => ^type
                     }
                   ]
                 }
               }
             } =
               conn
               |> get(Routes.profile_execution_path(conn, :show, id))
               |> json_response(:ok)
    end

    @tag authentication: [user_name: "not_an_admin"]
    @tag permissions: [:view_data_structure]
    test "returns an Forbidden response when user misses view_data_structures_profile permission",
         %{
           conn: conn,
           executions: [execution | _]
         } do
      %{id: id} = execution

      assert %{
               "errors" => %{"detail" => "Invalid authorization"}
             } =
               conn
               |> get(Routes.profile_execution_path(conn, :show, id))
               |> json_response(:forbidden)
    end

    @tag authentication: [user_name: "not_an_admin"]
    @tag permissions: [:view_data_structures_profile]
    test "returns an Forbidden response when user misses view_data_structure permission", %{
      conn: conn,
      executions: [execution | _]
    } do
      %{id: id} = execution

      assert %{
               "errors" => %{"detail" => "Invalid authorization"}
             } =
               conn
               |> get(Routes.profile_execution_path(conn, :show, id))
               |> json_response(:forbidden)
    end

    @tag authentication: [user_name: "not_an_admin"]
    test "returns an Forbidden response when user has no permissions", %{
      conn: conn,
      executions: [execution | _]
    } do
      %{id: id} = execution

      assert %{
               "errors" => %{"detail" => "Invalid authorization"}
             } =
               conn
               |> get(Routes.profile_execution_path(conn, :show, id))
               |> json_response(:forbidden)
    end
  end
end

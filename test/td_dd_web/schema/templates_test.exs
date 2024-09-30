defmodule TdDdWeb.Schema.TemplatesTest do
  use TdDdWeb.ConnCase

  @templates """
  query Templates($scope: String, $domainIds: [ID]) {
    templates(scope: $scope, domainIds: $domainIds) {
      id
      name
      label
      scope
      content
    }
  }
  """

  @template """
  query Template($name: String!, $domainIds: [ID]) {
    template(name: $name, domainIds: $domainIds) {
      id
      name
      label
      scope
      content
    }
  }
  """

  describe "templates query" do
    @tag authentication: [role: "user"]
    test "returns data when queried by user", %{conn: conn} do
      %{content: content} = CacheHelpers.insert_template(%{scope: "qe"})

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

    @tag authentication: [role: "user"]
    test "returns data when queried by user with multiple domains", %{conn: conn} do
      role_name = "test_role"

      %{id: domain_id_1} = CacheHelpers.insert_domain()
      %{id: domain_id_2} = CacheHelpers.insert_domain()
      %{id: user_id_1, full_name: full_name_1} = CacheHelpers.insert_user()
      %{id: user_id_2, full_name: full_name_2} = CacheHelpers.insert_user()
      %{id: user_id_3, full_name: full_name_3} = CacheHelpers.insert_user()
      CacheHelpers.insert_acl(domain_id_1, role_name, [user_id_1, user_id_2])
      CacheHelpers.insert_acl(domain_id_2, role_name, [user_id_2, user_id_3])

      CacheHelpers.insert_template(%{
        content: [
          %{
            "name" => "test-group",
            "fields" => [
              %{
                "name" => "name1",
                "type" => "user",
                "values" => %{"role_users" => role_name}
              }
            ]
          }
        ]
      })

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @templates,
                 "variables" => %{"domainIds" => [domain_id_1, domain_id_2]}
               })
               |> json_response(:ok)

      assert response["errors"] == nil
      assert %{"templates" => [template]} = data
      assert %{"content" => [%{"fields" => [%{"values" => values}]}]} = template
      assert %{"role_users" => ^role_name, "processed_users" => processed_users} = values
      assert Enum.sort(processed_users) == Enum.sort([full_name_1, full_name_2, full_name_3])
    end

    @tag authentication: [role: "user"]
    test "returns data ignoring empty domain string", %{conn: conn} do
      %{content: content} = CacheHelpers.insert_template(%{scope: "qe"})

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @templates,
                 "variables" => %{"scope" => "qe", "domainIds" => [""]}
               })
               |> json_response(:ok)

      assert response["errors"] == nil
      assert %{"templates" => [template]} = data
      assert %{"content" => ^content} = template
    end

    @tag authentication: [role: "agent"]
    test "returns data when queried actions scope by agent", %{conn: conn} do
      CacheHelpers.insert_template(%{scope: "actions"})

      assert %{"data" => _} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @templates,
                 "variables" => %{"scope" => "actions"}
               })
               |> json_response(:ok)

      assert response["errors"] == nil
    end
  end

  describe "template query" do
    @tag authentication: [role: "user"]
    test "returns data when queried by user", %{conn: conn} do
      %{content: content, name: name} = CacheHelpers.insert_template(%{scope: "dd"})

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @template,
                 "variables" => %{"name" => name}
               })
               |> json_response(:ok)

      assert response["errors"] == nil
      assert %{"template" => template} = data
      assert %{"content" => ^content} = template
    end

    @tag authentication: [role: "user"]
    test "returns data when queried by user with multiple domains", %{conn: conn} do
      role_name = "test_role"

      %{id: domain_id_1} = CacheHelpers.insert_domain()
      %{id: domain_id_2} = CacheHelpers.insert_domain()
      %{id: user_id_1, full_name: full_name_1} = CacheHelpers.insert_user()
      %{id: user_id_2, full_name: full_name_2} = CacheHelpers.insert_user()
      %{id: user_id_3, full_name: full_name_3} = CacheHelpers.insert_user()
      CacheHelpers.insert_acl(domain_id_1, role_name, [user_id_1, user_id_2])
      CacheHelpers.insert_acl(domain_id_2, role_name, [user_id_2, user_id_3])

      template_name = "template_name"

      CacheHelpers.insert_template(%{
        name: template_name,
        content: [
          %{
            "name" => "test-group",
            "fields" => [
              %{
                "name" => "name1",
                "type" => "user",
                "values" => %{"role_users" => role_name}
              }
            ]
          }
        ]
      })

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @template,
                 "variables" => %{
                   "name" => template_name,
                   "domainIds" => [domain_id_1, domain_id_2]
                 }
               })
               |> json_response(:ok)

      assert response["errors"] == nil
      assert %{"template" => template} = data
      assert %{"content" => [%{"fields" => [%{"values" => values}]}]} = template
      assert %{"role_users" => ^role_name, "processed_users" => processed_users} = values
      assert Enum.sort(processed_users) == Enum.sort([full_name_1, full_name_2, full_name_3])
    end

    @tag authentication: [role: "user"]
    test "returns data ignoring empty domain string", %{conn: conn} do
      %{content: content, name: name} = CacheHelpers.insert_template(%{scope: "qe"})

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @template,
                 "variables" => %{"name" => name, "domainIds" => [""]}
               })
               |> json_response(:ok)

      assert response["errors"] == nil
      assert %{"template" => template} = data
      assert %{"content" => ^content} = template
    end
  end
end

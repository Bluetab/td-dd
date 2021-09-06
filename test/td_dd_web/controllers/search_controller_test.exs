defmodule TdDdWeb.SearchControllerTest do
  use TdDdWeb.ConnCase


  # alias TdCache.ConceptCache
  alias TdCache.TaxonomyCache

  # @business_concept_id "42"

  setup_all do
    %{id: domain_id} = domain = build(:domain)
    TaxonomyCache.put_domain(domain)
  #   ConceptCache.put(%{id: @business_concept_id, name: "Concept", domain_id: domain_id})

    on_exit(fn ->
      TaxonomyCache.delete_domain(domain_id)
    end)

    [domain: domain]
  end

  # setup tags do
  #   # domain_id = get_in(tags, [:domain, :id])
  #   # rule = insert(:rule, business_concept_id: @business_concept_id, domain_id: domain_id)
  #   # implementation = insert(:implementation, rule: rule)
  #   # [implementation: implementation, rule: rule]
  #   grant = insert(:grant) |> IO.inspect(label: "SETUP TAGS GRANT")
  #   [grant: grant]
  # end

  describe "index" do

    setup :create_grant

    @tag authentication: [role: "admin"]
    test "admin can search grants", %{conn: conn} do
      assert %{"data" => [_]} =
               conn
               |> post(Routes.search_path(conn, :search_grants))
               |> json_response(:ok)

    end

    @tag authentication: [role: "user"]
    test "user with permissions can search grants", %{
      conn: conn,
      claims: %{user_id: user_id},
      domain: %{id: domain_id}
    } do
    #   assert %{"data" => []} =
    #            conn
    #            |> post(Routes.search_path(conn, :search_rules))
    #            |> json_response(:ok)

      create_acl_entry(user_id, "domain", domain_id, [:view_grants])

      assert %{"data" => [_]} =
               conn
               |> post(Routes.search_path(conn, :search_grants))
               |> json_response(:ok)
    end


    @tag authentication: [role: "user"]
    test "user without permissions cannot search grants", %{
      conn: conn,
      claims: %{user_id: user_id},
      domain: %{id: domain_id}
    } do
    #   assert %{"data" => []} =
    #            conn
    #            |> post(Routes.search_path(conn, :search_rules))
    #            |> json_response(:ok)

      #create_acl_entry(user_id, "domain", domain_id, [:view_grants])

      assert %{"data" => []} =
               conn
               |> post(Routes.search_path(conn, :search_grants))# |> IO.inspect(label: "post")
               |> json_response(:ok) |> IO.inspect(label: "json_response(:ok)")
    end


  end







  defp create_grant(context) do
    IO.puts("CREATE_GRANT")
    grant =
      case context do
        %{domain: domain} ->
          data_structure = insert(:data_structure, domain_id: domain.id, domain: domain)
          data_structure_version = insert(:data_structure_version, data_structure: data_structure)
          insert(:grant, data_structure_version: data_structure_version, data_structure: data_structure)
        _ ->
          insert(:grant)
      end

    [grant: grant]
  end






end

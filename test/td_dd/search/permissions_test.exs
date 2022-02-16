defmodule TdDd.Search.PermissionsTest do
  use TdDdWeb.ConnCase

  alias TdDd.Search.Permissions

  describe "Permissions.get_search_permissions/2 for structures" do
    @tag authentication: [role: "admin"]
    test "returns a map with values :all for admin role", %{claims: claims} do
      assert Permissions.get_search_permissions(claims, :link_data_structure) ==
               %{"link_data_structure" => :all}

      assert Permissions.get_search_permissions(claims, :view_data_structure) ==
               %{"view_data_structure" => :all}
    end

    @tag authentication: [user_name: "not_an_admin"]
    test "returns a map with :none values for regular users", %{claims: claims} do
      assert Permissions.get_search_permissions(claims, :link_data_structure) ==
               %{"link_data_structure" => :none}

      assert Permissions.get_search_permissions(claims, :view_data_structure) ==
               %{"view_data_structure" => :none}
    end

    @tag authentication: [user_name: "not_an_admin"]
    test "includes :all values for default permissions", %{claims: claims} do
      CacheHelpers.put_default_permissions(["link_data_structure", "view_data_structure", "foo"])

      assert Permissions.get_search_permissions(claims, :link_data_structure) ==
               %{"link_data_structure" => :all}

      assert Permissions.get_search_permissions(claims, :view_data_structure) ==
               %{"view_data_structure" => :all}
    end

    @tag authentication: [user_name: "not_an_admin"]
    test "includes domain_id values for session permissions, excepting defaults", %{
      claims: claims
    } do
      %{id: id1} = CacheHelpers.insert_domain()
      %{id: id2} = CacheHelpers.insert_domain(parent_id: id1)
      %{id: id3} = CacheHelpers.insert_domain()

      put_session_permissions(claims, %{
        "link_data_structure" => [id1],
        "view_data_structure" => [id3]
      })

      assert Permissions.get_search_permissions(claims, :link_data_structure) ==
               %{"link_data_structure" => [id2, id1]}

      assert Permissions.get_search_permissions(claims, :view_data_structure) ==
               %{"view_data_structure" => [id3]}

      CacheHelpers.put_default_permissions(["view_data_structure", "foo"])

      assert Permissions.get_search_permissions(claims, :view_data_structure) ==
               %{"view_data_structure" => :all}
    end
  end

  describe "Permissions.get_search_permissions/2 for rules" do
    @tag authentication: [role: "admin"]
    test "returns a map with values :all for admin role", %{claims: claims} do
      assert Permissions.get_search_permissions(claims, :rules) == %{
               "execute_quality_rule_implementations" => :all,
               "manage_confidential_business_concepts" => :all,
               "view_quality_rule" => :all
             }
    end

    @tag authentication: [user_name: "not_an_admin"]
    test "returns a map with :none values for regular users", %{claims: claims} do
      assert Permissions.get_search_permissions(claims, :rules) == %{
               "execute_quality_rule_implementations" => :none,
               "manage_confidential_business_concepts" => :none,
               "view_quality_rule" => :none
             }
    end

    @tag authentication: [user_name: "not_an_admin"]
    test "includes :all values for default permissions", %{claims: claims} do
      CacheHelpers.put_default_permissions(["view_quality_rule", "foo"])

      assert Permissions.get_search_permissions(claims, :rules) == %{
               "execute_quality_rule_implementations" => :none,
               "manage_confidential_business_concepts" => :none,
               "view_quality_rule" => :all
             }
    end

    @tag authentication: [user_name: "not_an_admin"]
    test "includes domain_id values for session permissions, excepting defaults", %{
      claims: claims
    } do
      CacheHelpers.put_default_permissions(["view_quality_rule", "foo"])
      %{id: id1} = CacheHelpers.insert_domain()
      %{id: id2} = CacheHelpers.insert_domain(parent_id: id1)
      %{id: id3} = CacheHelpers.insert_domain()

      put_session_permissions(claims, %{
        "manage_confidential_business_concepts" => [id1],
        "execute_quality_rule_implementations" => [id3]
      })

      assert Permissions.get_search_permissions(claims, :rules) == %{
               "execute_quality_rule_implementations" => [id3],
               "manage_confidential_business_concepts" => [id2, id1],
               "view_quality_rule" => :all
             }
    end
  end

  describe "Permissions.get_search_permissions/2 for grants" do
    @tag authentication: [role: "admin"]
    test "returns a map with values :all for admin role", %{claims: claims} do
      assert Permissions.get_search_permissions(claims, :grants) == %{
               "manage_grants" => :all,
               "view_grants" => :all
             }
    end

    @tag authentication: [user_name: "not_an_admin"]
    test "returns a map with :none values for regular users", %{claims: claims} do
      assert Permissions.get_search_permissions(claims, :grants) == %{
               "manage_grants" => :none,
               "view_grants" => :none
             }
    end

    @tag authentication: [user_name: "not_an_admin"]
    test "includes :all values for default permissions", %{claims: claims} do
      CacheHelpers.put_default_permissions(["view_grants", "foo"])

      assert Permissions.get_search_permissions(claims, :grants) == %{
               "manage_grants" => :none,
               "view_grants" => :all
             }
    end

    @tag authentication: [user_name: "not_an_admin"]
    test "includes domain_id values for session permissions, excepting defaults", %{
      claims: claims
    } do
      CacheHelpers.put_default_permissions(["view_grants", "foo"])
      %{id: id1} = CacheHelpers.insert_domain()
      %{id: id2} = CacheHelpers.insert_domain(parent_id: id1)
      %{id: id3} = CacheHelpers.insert_domain()

      put_session_permissions(claims, %{
        "manage_grants" => [id1],
        "view_grants" => [id3]
      })

      assert Permissions.get_search_permissions(claims, :grants) == %{
               "manage_grants" => [id2, id1],
               "view_grants" => :all
             }
    end
  end
end

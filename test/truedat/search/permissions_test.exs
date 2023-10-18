defmodule Truedat.Search.PermissionsTest do
  use ExUnit.Case
  use TdDd.DataCase

  alias Truedat.Search.Permissions

  describe "Permissions.get_search_permissions/2" do
    test "returns a map with values :all for admin role" do
      claims = claims("admin")

      assert Permissions.get_search_permissions(["foo", "bar"], claims) == %{
               "foo" => :all,
               "bar" => :all
             }
    end

    test "returns a map with values :all for service role" do
      claims = claims("service")

      assert Permissions.get_search_permissions(["foo", "bar"], claims) == %{
               "foo" => :all,
               "bar" => :all
             }
    end

    test "returns a map with values :none for user role" do
      claims = claims()

      assert Permissions.get_search_permissions(["foo", "bar"], claims) == %{
               "foo" => :none,
               "bar" => :none
             }
    end

    test "includes :all values for default permissions" do
      claims = claims()
      CacheHelpers.put_default_permissions(["foo"])

      assert Permissions.get_search_permissions(["foo", "bar"], claims) == %{
               "foo" => :all,
               "bar" => :none
             }
    end

    test "includes domain_id values for session permissions" do
      claims = claims()

      CacheHelpers.put_default_permissions(["baz"])
      %{id: id1} = CacheHelpers.insert_domain()
      %{id: id2} = CacheHelpers.insert_domain(parent_id: id1)
      %{id: id3} = CacheHelpers.insert_domain()

      CacheHelpers.put_session_permissions(claims, %{
        "foo" => [id1],
        "bar" => [id2],
        "baz" => [id3]
      })

      assert Permissions.get_search_permissions(["foo", "bar", "baz", "xyzzy"], claims) == %{
               "foo" => [id2, id1],
               "bar" => [id2],
               "baz" => :all,
               "xyzzy" => :none
             }
    end
  end

  describe "Permissions.get_roles_by_user/2" do
    test "returns a list with only roles for admin role" do
      claims = claims("admin")

      CacheHelpers.put_permissions_on_roles(%{"approve_grant_request" => ["baz", "faz"]})

      assert Permissions.get_roles_by_user(:approve_grant_request, claims) == ["baz", "faz"]
    end

    test "returns a list with roles for non_admin user" do
      %{user_id: user_id} = claims = build(:claims, role: "user")

      CacheHelpers.insert_user(id: user_id, role: "user")

      %{id: id1} = CacheHelpers.insert_domain()
      %{id: id2} = CacheHelpers.insert_domain(parent_id: id1)
      %{id: id3} = CacheHelpers.insert_domain()

      CacheHelpers.put_permissions_on_roles(%{"approve_grant_request" => ["foo", "bar"]})

      CacheHelpers.put_session_permissions(claims, %{
        "foo" => [id1],
        "bar" => [id2],
        "baz" => [id3]
      })

      CacheHelpers.insert_acl(id1, "foo", [user_id])
      CacheHelpers.insert_acl(id2, "bar", [user_id])

      assert Permissions.get_roles_by_user(:approve_grant_request, claims) == ["bar", "foo"]
    end

    test "returns a empty list non_admin user without permissions" do
      claims = build(:claims, role: "user")

      CacheHelpers.put_permissions_on_roles(%{"approve_grant_request" => ["baz", "faz"]})

      assert Permissions.get_roles_by_user(:approve_grant_request, claims) == []
    end
  end

  defp claims(role \\ "user") do
    %{jti: Ecto.UUID.generate(), role: role, exp: DateTime.utc_now() |> DateTime.add(10)}
  end
end

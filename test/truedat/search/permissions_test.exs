defmodule Truedat.Search.PermissionsTest do
  use ExUnit.Case

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

  defp claims(role \\ "user") do
    %{jti: Ecto.UUID.generate(), role: role, exp: DateTime.utc_now() |> DateTime.add(10)}
  end
end

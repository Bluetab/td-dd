defmodule Truedat.Auth.Plug.CurrentResourceTest do
  use TdDdWeb.ConnCase

  alias Truedat.Auth.Plug.CurrentResource

  describe "call/2" do
    test "assigns current_resource from Guardian claims", %{conn: conn} do
      claims = build(:claims, role: "admin")

      conn =
        conn
        |> Guardian.Plug.put_current_resource(claims)
        |> CurrentResource.call([])

      assert conn.assigns[:current_resource] == claims
      assert conn.private[:absinthe][:context][:claims] == claims
    end

    test "handles connection without authentication", %{conn: conn} do
      conn = CurrentResource.call(conn, [])

      assert conn.assigns[:current_resource] == nil
      assert conn.private[:absinthe][:context][:claims] == nil
    end

    test "assigns claims for user role", %{conn: conn} do
      claims = build(:claims, role: "user")

      conn =
        conn
        |> Guardian.Plug.put_current_resource(claims)
        |> CurrentResource.call([])

      assert conn.assigns[:current_resource] == claims
    end

    test "assigns claims for service role", %{conn: conn} do
      claims = build(:claims, role: "service")

      conn =
        conn
        |> Guardian.Plug.put_current_resource(claims)
        |> CurrentResource.call([])

      assert conn.assigns[:current_resource] == claims
    end
  end

  describe "init/1" do
    test "returns options unchanged" do
      assert CurrentResource.init([]) == []
      assert CurrentResource.init(foo: :bar) == [foo: :bar]
    end
  end
end

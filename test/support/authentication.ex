defmodule TdCxWeb.Authentication do
  @moduledoc """
  This module defines the functions required to
  add auth headers to requests
  """
  import Plug.Conn

  alias Phoenix.ConnTest
  alias TdCx.Auth.Claims
  alias TdCx.Auth.Guardian
  alias TdCx.Permissions.MockPermissionResolver

  def put_auth_headers(conn, jwt) do
    conn
    |> put_req_header("content-type", "application/json")
    |> put_req_header("authorization", "Bearer #{jwt}")
  end

  def create_user_auth_conn(%Claims{role: role} = claims) do
    {:ok, jwt, full_claims} = Guardian.encode_and_sign(claims, %{role: role})
    {:ok, claims} = Guardian.resource_from_claims(full_claims)

    conn =
      ConnTest.build_conn()
      |> put_auth_headers(jwt)

    register_token(jwt)
    [conn: conn, jwt: jwt, claims: claims]
  end

  def create_claims(user_name, opts \\ []) do
    user_id = Integer.mod(:binary.decode_unsigned(user_name), 100_000)
    role = Keyword.get(opts, :role, "user")
    is_admin = role === "admin"
    %Claims{user_id: user_id, is_admin: is_admin, role: role, user_name: user_name}
  end

  defp register_token(token) do
    with {:ok, resource} <- Guardian.decode_and_verify(token),
         pid when is_pid(pid) <- Process.whereis(MockPermissionResolver) do
      MockPermissionResolver.register_token(resource)
    end

    token
  end
end

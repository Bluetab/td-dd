defmodule TdDqWeb.Authentication do
  @moduledoc """
  This module defines the functions required to add auth headers to requests
  """
  alias Plug.Conn
  alias TdDq.Auth.Claims
  alias TdDq.Auth.Guardian

  def put_auth_headers(conn, jwt) do
    conn
    |> Conn.put_req_header("content-type", "application/json")
    |> Conn.put_req_header("authorization", "Bearer #{jwt}")
  end

  def create_user_auth_conn(%{} = claims) do
    %{jwt: jwt, claims: claims} = authenticate(claims)

    conn =
      Phoenix.ConnTest.build_conn()
      |> put_auth_headers(jwt)

    {:ok, %{conn: conn, jwt: jwt, claims: claims}}
  end

  def create_claims(opts) do
    role = Keyword.get(opts, :role, "user")
    user_name = Keyword.get(opts, :user_name, "joe")
    %{id: user_id} = CacheHelpers.insert_user(user_name: user_name)

    %Claims{
      user_id: user_id,
      user_name: user_name,
      role: role
    }
  end

  def assign_permissions({:ok, %{claims: claims} = state}, [_ | _] = permissions) do
    %{id: domain_id} = domain = CacheHelpers.insert_domain()
    CacheHelpers.put_session_permissions(claims, domain_id, permissions)
    {:ok, Map.put(state, :domain, domain)}
  end

  def assign_permissions(state, _), do: state

  defp authenticate(%{role: role} = claims) do
    {:ok, jwt, %{"jti" => jti, "exp" => exp} = full_claims} =
      Guardian.encode_and_sign(claims, %{role: role})

    {:ok, claims} = Guardian.resource_from_claims(full_claims)
    {:ok, _} = Guardian.decode_and_verify(jwt)
    TdCache.SessionCache.put(jti, exp)
    %{jwt: jwt, claims: claims}
  end
end

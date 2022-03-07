defmodule TdDdWeb.Authentication do
  @moduledoc """
  This module defines the functions required to add auth headers to requests
  """
  alias Plug.Conn
  alias TdDd.Auth.Claims
  alias TdDd.Auth.Guardian

  def put_auth_headers(conn, jwt) do
    conn
    |> Conn.put_req_header("content-type", "application/json")
    |> Conn.put_req_header("authorization", "Bearer #{jwt}")
  end

  def create_user_auth_conn(%Claims{role: role} = claims) do
    {:ok, jwt, full_claims} = Guardian.encode_and_sign(claims, %{role: role})
    {:ok, claims} = Guardian.resource_from_claims(full_claims)
    register_token(jwt)

    conn =
      Phoenix.ConnTest.build_conn()
      |> put_auth_headers(jwt)

    {:ok, %{conn: conn, jwt: jwt, claims: claims}}
  end

  def create_claims(opts \\ []) do
    role = Keyword.get(opts, :role, "user")
    user_name = Keyword.get(opts, :user_name, "joe")

    user_id =
      Keyword.get(opts, :user_id, Integer.mod(:binary.decode_unsigned(user_name), 100_000))

    %Claims{
      user_id: user_id,
      user_name: user_name,
      role: role
    }
  end

  def assign_permissions(
        {:ok, %{claims: %{user_id: user_id}} = state},
        [_ | _] = permissions,
        nil = _domain_id
      ) do
    domain = CacheHelpers.insert_domain()
    create_acl_entry(user_id, domain.id, permissions)
    {:ok, Map.put(state, :domain, domain)}
  end

  def assign_permissions(
        {:ok, %{claims: %{user_id: user_id}} = state},
        [_ | _] = permissions,
        domain_id
      ) do
    domain = CacheHelpers.insert_domain(%{id: domain_id})
    create_acl_entry(user_id, domain.id, permissions)
    {:ok, Map.put(state, :domain, domain)}
  end

  def assign_permissions(state, _, _), do: state

  def build_user_token(%Claims{role: role} = claims) do
    case Guardian.encode_and_sign(claims, %{role: role}) do
      {:ok, jwt, _full_claims} -> register_token(jwt)
      _ -> raise "Problems encoding and signing a claims"
    end
  end

  def build_user_token(opts) when is_list(opts) do
    opts
    |> create_claims()
    |> build_user_token()
  end

  def build_user_token(user_name) when is_binary(user_name) do
    build_user_token(user_name: user_name, role: "user")
  end

  defp register_token(token) do
    case Guardian.decode_and_verify(token) do
      {:ok, resource} -> MockPermissionResolver.register_token(resource)
      _ -> raise "Problems decoding and verifying token"
    end

    token
  end

  def create_acl_entry(user_id, domain_id, permissions) do
    create_acl_entry(user_id, "domain", domain_id, permissions)
  end

  def create_acl_entry(user_id, resource_type, resource_id, permissions) do
    MockPermissionResolver.create_acl_entry(%{
      principal_type: "user",
      principal_id: user_id,
      resource_type: resource_type,
      resource_id: resource_id,
      permissions: permissions
    })
  end
end

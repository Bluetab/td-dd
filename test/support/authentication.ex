defmodule TdDqWeb.Authentication do
  @moduledoc """
  This module defines the functions required to add auth headers to requests
  """
  import Plug.Conn

  alias Phoenix.ConnTest
  alias TdDq.Auth.Claims
  alias TdDq.Auth.Guardian
  alias TdDq.Permissions.MockPermissionResolver

  def put_auth_headers(conn, jwt) do
    conn
    |> put_req_header("content-type", "application/json")
    |> put_req_header("authorization", "Bearer #{jwt}")
  end

  def create_user_auth_conn(%{role: role} = claims) do
    {:ok, jwt, full_claims} = Guardian.encode_and_sign(claims, %{role: role})
    {:ok, claims} = Guardian.resource_from_claims(full_claims)

    conn =
      ConnTest.build_conn()
      |> put_auth_headers(jwt)

    {:ok, %{conn: conn, jwt: jwt, claims: claims}}
  end

  def create_user_auth_conn(user, role) do
    {:ok, resp} = create_user_auth_conn(user)
    register_token(Map.get(resp, :jwt))

    case role do
      nil -> :ok
      _ -> create_acl_entry(user, role)
    end

    {:ok, resp}
  end

  def create_claims(user_name, opts \\ []) do
    user_id = :rand.uniform(100_000)
    role = Keyword.get(opts, :role, "user")
    is_admin = role === "admin"

    %Claims{
      user_id: user_id,
      user_name: user_name,
      role: role,
      is_admin: is_admin
    }
  end

  def build_user_token(%Claims{} = user) do
    case Guardian.encode_and_sign(user) do
      {:ok, jwt, _full_claims} -> jwt
      _ -> raise "Problems encoding and signing a user"
    end
  end

  def build_user_token(user_name, opts \\ []) when is_binary(user_name) do
    user_name
    |> create_claims(opts)
    |> build_user_token()
  end

  defp register_token(token) do
    case Guardian.decode_and_verify(token) do
      {:ok, resource} -> MockPermissionResolver.register_token(resource)
      _ -> raise "Problems decoding and verifying token"
    end

    token
  end

  defp create_acl_entry(%Claims{user_id: user_id}, role_name) do
    MockPermissionResolver.create_acl_entry(%{
      principal_id: user_id,
      principal_type: "user",
      resource_id: 1,
      resource_type: "domain",
      role_name: role_name
    })
  end
end

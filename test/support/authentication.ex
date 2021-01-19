defmodule TdDdWeb.Authentication do
  @moduledoc """
  This module defines the functions required to add auth headers to requests
  """
  alias Plug.Conn
  alias TdDd.Auth.Claims
  alias TdDd.Auth.Guardian
  alias TdDd.Permissions.MockPermissionResolver

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
    is_admin = role === "admin"

    user_name =
      case Keyword.get(opts, :user_name) do
        nil -> if is_admin, do: "app-admin", else: "user"
        name -> name
      end

    %Claims{
      user_id: Integer.mod(:binary.decode_unsigned(user_name), 100_000),
      user_name: user_name,
      role: role,
      is_admin: is_admin
    }
  end

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
    user_name
    |> role_opts()
    |> build_user_token()
  end

  defp role_opts("app-admin"), do: [user_name: "app-admin", role: "admin"]
  defp role_opts(user_name), do: [user_name: user_name, role: "user"]

  defp register_token(token) do
    case Guardian.decode_and_verify(token) do
      {:ok, resource} -> MockPermissionResolver.register_token(resource)
      _ -> raise "Problems decoding and verifying token"
    end

    token
  end
end

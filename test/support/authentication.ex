defmodule TdDqWeb.Authentication do
  @moduledoc """
  This module defines the functions required to
  add auth headers to requests
  """
  alias Phoenix.ConnTest
  alias TdDq.Accounts.User
  alias TdDq.Auth.Guardian
  alias TdDq.Permissions.MockPermissionResolver
  import Plug.Conn
  @headers {"Content-type", "application/json"}

  # OLD
  # def sign_in(user_name) do
  #   user = %{"user_name": user_name}
  #   {:ok, _jwt, _full_claims} = Guardian.encode_and_sign(user)
  # end

  def put_auth_headers(conn, jwt) do
    conn
    |> put_req_header("content-type", "application/json")
    |> put_req_header("authorization", "Bearer #{jwt}")
  end

  def create_user_auth_conn(user) do
    {:ok, jwt, full_claims} = Guardian.encode_and_sign(user)
    conn = ConnTest.build_conn()
    conn = put_auth_headers(conn, jwt)
    {:ok, %{conn: conn, jwt: jwt, claims: full_claims, user: user}}
  end

  def create_user_auth_conn(user, :not_admin) do
    {:ok, resp} = create_user_auth_conn(user)
    register_token(Map.get(resp, :jwt))
    {:ok, resp}
  end

  def get_header(token) do
    [@headers, {"authorization", "Bearer #{token}"}]
  end

  def create_user(user_name, opts \\ []) do
    id = Integer.mod(:binary.decode_unsigned(user_name), 100_000)
    is_admin = Keyword.get(opts, :is_admin, false)
    %TdDq.Accounts.User{id: id, is_admin: is_admin, user_name: user_name}
  end

  def build_user_token(%User{} = user) do
    case Guardian.encode_and_sign(user) do
      {:ok, jwt, _full_claims} -> jwt
      _ -> raise "Problems encoding and signing a user"
    end
  end

  def build_user_token(user_name, opts \\ []) when is_binary(user_name) do
    build_user_token(create_user(user_name, opts))
  end

  def get_user_token(user_name) do
    build_user_token(user_name, is_admin: user_name == "app-admin")
  end

  defp register_token(token) do
    case Guardian.decode_and_verify(token) do
      {:ok, resource} -> MockPermissionResolver.register_token(resource)
      _ -> raise "Problems decoding and verifying token"
    end

    token
  end
end

defmodule TdDdWeb.Authentication do
  @moduledoc """
  This module defines the functions required to
  add auth headers to requests
  """
  alias Phoenix.ConnTest
  alias TdDd.Accounts.User
  alias TdDd.Auth.Guardian
  import Plug.Conn

  @td_auth_api Application.get_env(:td_dd, :auth_service)[:api_service]

  @headers {"Content-type", "application/json"}

  def put_auth_headers(conn, jwt) do
    conn
    |> put_req_header("content-type", "application/json")
    |> put_req_header("authorization", "Bearer #{jwt}")
  end

  def recycle_and_put_headers(conn) do
    authorization_header = List.first(get_req_header(conn, "authorization"))
    conn
    |> ConnTest.recycle()
    |> put_req_header("authorization", authorization_header)
  end

  def create_user_auth_conn(user) do
    {:ok, jwt, full_claims} = Guardian.encode_and_sign(user)
    conn = ConnTest.build_conn()
    conn = put_auth_headers(conn, jwt)
    {:ok, %{conn: conn, jwt: jwt, claims: full_claims}}
  end

  def get_header(token) do
    [@headers, {"authorization", "Bearer #{token}"}]
  end

  # defp create_user(user_name, opts \\ []) do
  #   is_admin = Keyword.get(opts, :is_admin, false)
  #   password = Keyword.get(opts, :password, "secret")
  #   user = @td_auth_api.create_user(%{"user" => %{user_name: user_name, is_admin: is_admin, password: password}})
  #   user
  # end

  def find_or_create_user(user_name, opts \\ []) do
    user = case get_user_by_name(user_name) do
      nil ->
        is_admin = Keyword.get(opts, :is_admin, false)
        password = Keyword.get(opts, :password, "secret")
        @td_auth_api.create_user(%{"user" => %{user_name: user_name, is_admin: is_admin, password: password}})
      user -> user
    end
    user
  end

  def get_user_by_name(user_name) do
    @td_auth_api.get_user_by_name(user_name)
  end

  def get_users do
    @td_auth_api.index()
  end

  def build_user_token(%User{} = user) do
      case Guardian.encode_and_sign(user) do
        {:ok, jwt, _full_claims} -> jwt
        _ -> raise "Problems encoding and signing a user"
      end
  end

  def build_user_token(user_name, opts \\ []) when is_binary(user_name) do
    build_user_token(find_or_create_user(user_name, opts))
  end

  def get_user_token(user_name) do
    build_user_token(user_name, is_admin: user_name == "app-admin")
  end

end

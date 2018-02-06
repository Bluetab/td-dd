defmodule DataQualityWeb.Authentication do
  @moduledoc """
  This module defines the functions required to
  add auth headers to requests
  """
  alias Phoenix.ConnTest
  alias DataQuality.Auth.Guardian
  import Plug.Conn
  @headers {"Content-type", "application/json"}

  def sign_in(user_name) do
    user = %{"user_name": user_name}
    {:ok, _jwt, _full_claims} = Guardian.encode_and_sign(user)
  end

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

  def create_user_auth_conn(user_name) do
    user = %{"user_name": user_name}
    {:ok, jwt, full_claims} = Guardian.encode_and_sign(user)
    conn = ConnTest.build_conn()
    |> put_auth_headers(jwt)
    |> assign(:current_user, user)
    {:ok, %{conn: conn, jwt: jwt, claims: full_claims}}
  end

  def get_header(token) do
    [@headers, {"authorization", "Bearer #{token}"}]
  end

end

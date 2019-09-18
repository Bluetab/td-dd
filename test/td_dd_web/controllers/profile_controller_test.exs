defmodule TdDdWeb.ProfileControllerTest do
  use TdDdWeb.ConnCase

  # alias TdDd.DataStructures
  # alias TdDd.DataStructures.Profile

  # @create_attrs %{
  #   value: %{}
  # }
  # @update_attrs %{
  #   value: %{}
  # }
  # @invalid_attrs %{value: nil}

  # def fixture(:profile) do
  #   {:ok, profile} = DataStructures.create_profile(@create_attrs)
  #   profile
  # end

  # setup %{conn: conn} do
  #   {:ok, conn: put_req_header(conn, "accept", "application/json")}
  # end

  # describe "index" do
  #   test "lists all profiles", %{conn: conn} do
  #     conn = get(conn, Routes.profile_path(conn, :index))
  #     assert json_response(conn, 200)["data"] == []
  #   end
  # end

  # describe "create profile" do
  #   test "renders profile when data is valid", %{conn: conn} do
  #     conn = post(conn, Routes.profile_path(conn, :create), profile: @create_attrs)
  #     assert %{"id" => id} = json_response(conn, 201)["data"]

  #     conn = get(conn, Routes.profile_path(conn, :show, id))

  #     assert %{
  #              "id" => id,
  #              "value" => {}
  #            } = json_response(conn, 200)["data"]
  #   end

  #   test "renders errors when data is invalid", %{conn: conn} do
  #     conn = post(conn, Routes.profile_path(conn, :create), profile: @invalid_attrs)
  #     assert json_response(conn, 422)["errors"] != %{}
  #   end
  # end

  # describe "update profile" do
  #   setup [:create_profile]

  #   test "renders profile when data is valid", %{conn: conn, profile: %Profile{id: id} = profile} do
  #     conn = put(conn, Routes.profile_path(conn, :update, profile), profile: @update_attrs)
  #     assert %{"id" => ^id} = json_response(conn, 200)["data"]

  #     conn = get(conn, Routes.profile_path(conn, :show, id))

  #     assert %{
  #              "id" => id,
  #              "value" => {}
  #            } = json_response(conn, 200)["data"]
  #   end

  #   test "renders errors when data is invalid", %{conn: conn, profile: profile} do
  #     conn = put(conn, Routes.profile_path(conn, :update, profile), profile: @invalid_attrs)
  #     assert json_response(conn, 422)["errors"] != %{}
  #   end
  # end

  # describe "delete profile" do
  #   setup [:create_profile]

  #   test "deletes chosen profile", %{conn: conn, profile: profile} do
  #     conn = delete(conn, Routes.profile_path(conn, :delete, profile))
  #     assert response(conn, 204)

  #     assert_error_sent 404, fn ->
  #       get(conn, Routes.profile_path(conn, :show, profile))
  #     end
  #   end
  # end

  # defp create_profile(_) do
  #   profile = fixture(:profile)
  #   {:ok, profile: profile}
  # end
end

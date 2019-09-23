defmodule TdDdWeb.SearchPermissionPlug do
  @moduledoc """
  A Plug which uses the referer header to determine which permission should
  be used to filter search results.
  """

  import Plug.Conn

  def init(options) do
    options
  end

  def call(conn, _opts) do
    permission = get_permission(conn)
    conn |> assign(:search_permission, permission)
  end

  defp get_permission(conn) do
    case get_req_header(conn, "referer") do
      [referer] ->
        cond do
          String.match?(referer, ~r/\/concepts\//) -> :link_data_structure
          String.match?(referer, ~r/\/ingests\//) -> :link_data_structure
          String.match?(referer, ~r/\/rules\//) -> :link_data_structure
          true -> :view_data_structure
        end

      _ ->
        :view_data_structure
    end
  end
end

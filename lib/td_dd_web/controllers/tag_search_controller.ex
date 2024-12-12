defmodule TdDdWeb.TagSearchController do
  alias TdDd.DataStructures.Tags
  use TdDdWeb, :controller

  @allowed_params ["since", "min_id", "size"]

  def search(conn, params) do
    tags =
      params
      |> Enum.reduce(%{}, fn
        {key, value}, acc when key in @allowed_params ->
          Map.put(acc, String.to_atom(key), value)

        _, acc ->
          acc
      end)
      |> Tags.list_tags()

    total_count = Enum.count(tags)

    conn
    |> put_resp_header("x-total-count", "#{total_count}")
    |> render("index.json", tags: tags)
  end
end

defmodule TdDdWeb.StructureTagSearchController do
  alias TdDd.DataStructures.StructureTags
  use TdDdWeb, :controller

  @allowed_params ["since", "min_id", "size"]

  def search(conn, params) do
    structure_tags =
      params
      |> Enum.reduce(%{}, fn
        {key, value}, acc when key in @allowed_params ->
          Map.put(acc, String.to_atom(key), value)

        _, acc ->
          acc
      end)
      |> StructureTags.list_structure_tags()

    total_count = Enum.count(structure_tags)

    conn
    |> put_resp_header("x-total-count", "#{total_count}")
    |> render("index.json", structure_tags: structure_tags)
  end
end

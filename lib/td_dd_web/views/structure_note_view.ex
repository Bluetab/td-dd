defmodule TdDdWeb.StructureNoteView do
  use TdDdWeb, :view
  alias TdDdWeb.StructureNoteView

  def render("index.json", %{structure_notes: structure_notes}) do
    %{data: render_many(structure_notes, StructureNoteView, "structure_note.json")}
  end

  def render("show.json", %{structure_note: structure_note, actions: _actions} = assigns) do
    %{data: render_one(structure_note, StructureNoteView, "structure_note.json"),
      _actions: render_one(assigns, __MODULE__, "actions.json")}
  end

  def render("show.json", %{structure_note: structure_note}) do
    %{data: render_one(structure_note, StructureNoteView, "structure_note.json")}
  end

  def render("structure_note.json", %{structure_note: structure_note}) do
    %{id: structure_note.id,
      status: structure_note.status,
      version: structure_note.version,
      df_content: structure_note.df_content}
  end

  def render("actions.json", %{structure_note: %{actions: actions, conn: conn}}) do
    {"location", location} = conn.resp_headers
    |> Enum.find(fn(header) ->
      case header do
        {"location", _location} -> true
        _ -> false
      end
    end)

    # [{"location", location}] = conn.resp_headers

    actions
    |> Enum.reduce(%{}, fn action, acc -> Map.put(acc, action,
      %{href: location,
        input: %{status: action},
        method: "PUT"
      }
    )end)
  end
end

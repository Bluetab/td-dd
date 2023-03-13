defmodule TdDdWeb.StructureNoteView do
  use TdDdWeb, :view

  alias TdCache.TemplateCache
  alias TdDdWeb.StructureNoteView
  alias TdDfLib.Format

  def render("index.json", %{
        structure_notes: structure_notes,
        actions: actions
      }) do
    %{
      data: render_many(structure_notes, StructureNoteView, "structure_note.json"),
      _actions: actions
    }
  end

  def render("index.json", %{structure_notes: structure_notes}) do
    %{data: render_many(structure_notes, StructureNoteView, "structure_note.json")}
  end

  def render("search.json", %{structure_notes: structure_notes}) do
    %{data: render_many(structure_notes, StructureNoteView, "search_structure_note.json")}
  end

  def render("show.json", %{structure_note: structure_note, actions: actions}) do
    %{
      data: render_one(structure_note, StructureNoteView, "structure_note.json"),
      _actions: actions
    }
  end

  def render("show.json", %{structure_note: structure_note}) do
    %{data: render_one(structure_note, StructureNoteView, "structure_note.json")}
  end

  def render(
        "structure_note.json",
        %{structure_note: %{_diff: [_ | _]} = structure_note}
      ) do
    %{
      id: structure_note.id,
      status: structure_note.status,
      version: structure_note.version,
      _diff: Map.get(structure_note, :_diff, []),
      updated_at: structure_note.updated_at,
      _actions: Map.get(structure_note, :actions, %{})
    }
    |> add_cache_content(structure_note)
  end

  def render("structure_note.json", %{structure_note: structure_note}) do
    %{
      id: structure_note.id,
      status: structure_note.status,
      version: structure_note.version,
      updated_at: structure_note.updated_at,
      _actions: Map.get(structure_note, :actions, %{})
    }
    |> add_cache_content(structure_note)
  end

  def render("search_structure_note.json", %{structure_note: structure_note}) do
    %{
      id: structure_note.id,
      status: structure_note.status,
      updated_at: structure_note.updated_at,
      data_structure_id: structure_note.data_structure_id,
      data_structure_external_id: Map.get(structure_note.data_structure, :external_id),
      version: structure_note.version
    }
    |> add_cache_content(structure_note)
  end

  defp add_cache_content(note, %{template_id: template_id} = structure_note) do
    {:ok, template} = TemplateCache.get(template_id)

    content =
      structure_note
      |> Map.get(:df_content)
      |> Format.enrich_content_values(template, [:system, :hierarchy])

    Map.put(note, :df_content, content)
  end

  defp add_cache_content(note, structure_note) do
    Map.put(note, :df_content, structure_note.df_content)
  end
end

defmodule TdDdWeb.StructureNoteView do
  use TdDdWeb, :view
  alias TdDdWeb.StructureNoteView

  def render("index.json", %{structure_notes: structure_notes}) do
    %{data: render_many(structure_notes, StructureNoteView, "structure_note.json")}
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
end

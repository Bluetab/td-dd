defmodule TdDdWeb.Schema.StructureNotes do
  @moduledoc """
  Absinthe schema definitions for quality structure_notes and related entities.
  """

  use Absinthe.Schema.Notation

  import Absinthe.Resolution.Helpers, only: [dataloader: 1]

  alias TdDdWeb.Resolvers

  object :structure_note_queries do
    @desc "Get a list of structure_notes"
    field :structure_notes, list_of(:structure_note) do
      arg(:filter, :structure_notes_filter)
      resolve(&Resolvers.StructureNotes.structure_notes/3)
    end
  end

  object :structure_note do
    field :id, non_null(:id)
    field :status, non_null(:string)
    field :data_structure, :data_structure, resolve: dataloader(TdDd.DataStructures)
  end

  @desc "Filters for Structure Notes"
  input_object :structure_notes_filter do

    @desc "List of statuses"
    field :statuses, list_of(:string)

    @desc "List of Systems"
    field :system_ids, list_of(:id)

    @desc "List of Domains"
    field :domain_ids, list_of(:id)
  end
end

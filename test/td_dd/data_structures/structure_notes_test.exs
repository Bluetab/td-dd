defmodule TdDd.DataStructures.StructureNotesTest do
  use TdDd.DataStructureCase

  import TdDd.TestOperators

  alias TdDd.DataStructures.StructureNotes

  @moduletag sandbox: :shared

  describe "structure_notes" do
    alias TdDd.DataStructures.StructureNote

    @user_id 1
    @valid_attrs %{df_content: %{}, status: :draft, version: 42}
    @update_attrs %{df_content: %{}, status: :published}
    @invalid_attrs %{df_content: nil, status: nil, version: nil}

    test "list_structure_notes/0 returns all structure_notes" do
      structure_note = insert(:structure_note)
      assert StructureNotes.list_structure_notes() <|> [structure_note]
    end

    test "list_structure_notes/1 returns all structure_notes for a data_structure" do
      %{data_structure_id: data_structure_id} = structure_note = insert(:structure_note)
      insert(:structure_note)
      assert StructureNotes.list_structure_notes(data_structure_id) <|> [structure_note]
    end

    test "list_structure_notes/1 returns all structure_notes filtered by params" do
      n1 = insert(:structure_note, status: :versioned, updated_at: ~N[2021-01-10 10:00:00])
      n2 = insert(:structure_note, status: :versioned, updated_at: ~N[2021-01-10 11:00:00])
      n3 = insert(:structure_note, status: :versioned, updated_at: ~N[2021-01-01 10:00:00])
      n4 = insert(:structure_note, status: :draft, updated_at: ~N[2021-01-10 10:00:00])

      filters = %{
        "updated_at" => "2021-01-02 10:00:00",
        "status" => "versioned"
      }

      assert StructureNotes.list_structure_notes(filters) <|> [n1, n2]
      assert StructureNotes.list_structure_notes(%{}) <|> [n1, n2, n3, n4]
      assert StructureNotes.list_structure_notes(%{"status" => :draft}) <|> [n4]
    end

    test "list_structure_notes/1 return ordered results paginated by id cursor" do
      page_size = 200

      structure_notes =
        Enum.map(1..5, fn _ ->
          Enum.map(1..page_size, fn _ -> insert(:structure_note) end)
        end)

      Enum.reduce(structure_notes, nil, fn chunk, id ->
        {last_chunk_id, _} = get_last_id_updated_at_notes(chunk)

        notes =
          StructureNotes.list_structure_notes(%{"cursor" => %{"id" => id, "size" => page_size}})

        assert ^page_size = Enum.count(notes)
        {last_note_id, _} = get_last_id_updated_at_notes(notes)
        assert ^last_chunk_id = last_note_id
        last_chunk_id
      end)
    end

    test "list_structure_notes/1 return ordered results paginated by updated_at and id cursor" do
      page_size = 200

      [chunk | rest_notes] =
        Enum.map(1..5, fn _ ->
          Enum.map(1..page_size, fn _ -> insert(:structure_note) end)
        end)

      {last_chunk_id, last_chunk_updated_at} = get_last_id_updated_at_notes(chunk)

      Enum.reduce(rest_notes, {last_chunk_id, last_chunk_updated_at}, fn chunk,
                                                                         {id, updated_at} ->
        {last_chunk_id, _} = get_last_id_updated_at_notes(chunk)

        notes =
          StructureNotes.list_structure_notes(%{
            "since" => updated_at,
            "cursor" => %{"id" => id, "size" => page_size}
          })

        assert ^page_size = Enum.count(notes)
        {last_note_id, _} = get_last_id_updated_at_notes(notes)
        assert ^last_chunk_id = last_note_id
        {last_chunk_id, updated_at}
      end)
    end

    test "get_structure_note!/1 returns the structure_note with given id" do
      structure_note = insert(:structure_note)
      assert StructureNotes.get_structure_note!(structure_note.id) <~> structure_note
    end

    test "get_latest_structure_note/1 returns the latest structure_note for a data_structure" do
      %{data_structure: data_structure} = insert(:structure_note, version: 1)
      insert(:structure_note, version: 2, data_structure: data_structure)
      latest_structure_note = insert(:structure_note, version: 3, data_structure: data_structure)
      insert(:structure_note)
      assert StructureNotes.get_latest_structure_note(data_structure.id) <~> latest_structure_note
    end

    test "create_structure_note/3 with valid data creates a structure_note and publishes event" do
      data_structure = insert(:data_structure)

      assert {:ok, %StructureNote{} = structure_note} =
               StructureNotes.create_structure_note(data_structure, @valid_attrs, @user_id)

      assert structure_note.df_content == %{}
      assert structure_note.status == :draft
      assert structure_note.version == 42
    end

    test "create_structure_note/3 with invalid data returns error changeset" do
      data_structure = insert(:data_structure)

      assert {:error, %Ecto.Changeset{}} =
               StructureNotes.create_structure_note(data_structure, @invalid_attrs, @user_id)
    end

    test "update_structure_note/3 with valid data updates the structure_note" do
      structure_note = insert(:structure_note)

      assert {:ok, %StructureNote{} = structure_note} =
               StructureNotes.update_structure_note(structure_note, @update_attrs, @user_id)

      assert structure_note.df_content == %{}
      assert structure_note.status == :published
    end

    test "update_structure_note/3 with invalid data returns error changeset" do
      structure_note = insert(:structure_note)

      assert {:error, %Ecto.Changeset{}} =
               StructureNotes.update_structure_note(structure_note, @invalid_attrs, @user_id)

      assert structure_note <~> StructureNotes.get_structure_note!(structure_note.id)
    end

    test "delete_structure_note/1 deletes the structure_note" do
      %{user_id: user_id} = build(:claims)
      structure_note = insert(:structure_note)

      assert {:ok, %StructureNote{}} =
               StructureNotes.delete_structure_note(structure_note, user_id)

      assert_raise Ecto.NoResultsError, fn ->
        StructureNotes.get_structure_note!(structure_note.id)
      end
    end

    test "change_structure_note/1 returns a structure_note changeset" do
      structure_note = insert(:structure_note)
      assert %Ecto.Changeset{} = StructureNotes.change_structure_note(structure_note)
    end
  end

  defp get_last_id_updated_at_notes(notes) do
    last_note = List.last(notes)
    id = last_note.id
    updated_at = NaiveDateTime.to_iso8601(last_note.updated_at)
    {id, updated_at}
  end
end

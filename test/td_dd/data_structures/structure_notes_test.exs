defmodule TdDd.DataStructures.StructureNotesTest do
  use TdDd.DataStructureCase

  import TdDd.TestOperators

  alias Ecto.Changeset
  alias TdDd.DataStructures.StructureNote
  alias TdDd.DataStructures.StructureNotes

  @moduletag sandbox: :shared
  @user_id 1

  setup do
    start_supervised!(TdDd.Search.StructureEnricher)

    alias_field = %{
      "cardinality" => "?",
      "label" => "alias",
      "name" => "alias",
      "type" => "string"
    }

    content = [%{"name" => "g1", "fields" => [alias_field]}]
    %{id: template_id} = CacheHelpers.insert_template(scope: "dd", content: content)
    data_structure_type = insert(:data_structure_type, template_id: template_id)

    [data_structure_type: data_structure_type]
  end

  describe "structure_notes" do
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

    test "list_structure_notes/1 return results paginated by offset ordered by updated_at and note id" do
      page_size = 200

      structure_notes =
        Enum.map(1..5, fn _ ->
          Enum.map(1..page_size, fn _ -> insert(:structure_note) end)
        end)

      Enum.reduce(structure_notes, 0, fn chunk, offset ->
        {last_chunk_id, _} = get_last_id_updated_at_notes(chunk)

        notes =
          StructureNotes.list_structure_notes(%{
            "cursor" => %{"offset" => offset, "size" => page_size}
          })

        assert ^page_size = Enum.count(notes)
        {last_note_id, _} = get_last_id_updated_at_notes(notes)
        assert ^last_chunk_id = last_note_id
        offset + Enum.count(notes)
      end)
    end

    test "list_structure_notes/1 return ordered results paginated by updated_at and id cursor" do
      page_size = 200

      inserted_notes =
        [chunk | rest_notes] =
        Enum.map(1..5, fn _ ->
          Enum.map(1..page_size, fn _ -> insert(:structure_note) end)
        end)

      {_last_chunk_id, last_chunk_updated_at} = get_last_id_updated_at_notes(chunk)

      total_post_notes =
        [chunk | rest_notes]
        |> List.flatten()
        |> Enum.filter(&(NaiveDateTime.to_iso8601(&1.updated_at) >= last_chunk_updated_at))
        |> Enum.count()

      assert {^total_post_notes, _} =
               Enum.reduce(inserted_notes, {0, last_chunk_updated_at}, fn _chunk,
                                                                          {offset, updated_at} ->
                 notes =
                   StructureNotes.list_structure_notes(%{
                     "since" => updated_at,
                     "cursor" => %{"offset" => offset, "size" => page_size}
                   })

                 {offset + Enum.count(notes), updated_at}
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

      params = %{"df_content" => %{}, "status" => "draft", "version" => 42}

      assert {:ok, %StructureNote{} = structure_note} =
               StructureNotes.create_structure_note(data_structure, params, @user_id)

      assert structure_note.df_content == %{}
      assert structure_note.status == :draft
      assert structure_note.version == 42
    end

    test "create_structure_note/3 with invalid data returns error changeset" do
      data_structure = insert(:data_structure)

      params = %{"df_content" => nil, "status" => nil, "version" => nil}

      assert {:error, %Changeset{}} =
               StructureNotes.create_structure_note(data_structure, params, @user_id)
    end

    test "update_structure_note/3 with valid data updates the structure_note" do
      structure_note = insert(:structure_note)

      params = %{"df_content" => %{}, "status" => "published"}

      assert {:ok, %{structure_note_update: structure_note}} =
               StructureNotes.update_structure_note(structure_note, params, @user_id)

      assert structure_note.df_content == %{}
      assert structure_note.status == :published
    end

    test "update_structure_note/3 with invalid data returns error changeset" do
      structure_note = insert(:structure_note)

      params = %{"df_content" => nil, "status" => nil, "version" => nil}

      assert {:error, :structure_note, %Changeset{}, _} =
               StructureNotes.update_structure_note(structure_note, params, @user_id)

      assert structure_note <~> StructureNotes.get_structure_note!(structure_note.id)
    end

    test "update_structure_note/3 updates structure alias when published", %{
      data_structure_type: type
    } do
      %{data_structure_id: data_structure_id} = insert(:data_structure_version, type: type.name)
      structure_note = insert(:structure_note, data_structure_id: data_structure_id)
      params = %{"df_content" => %{"alias" => "foo"}, "status" => "published"}

      assert {:ok, %{update_alias: structure}} =
               StructureNotes.update_structure_note(structure_note, params, @user_id)

      assert %{alias: "foo"} = structure
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
  end

  defp get_last_id_updated_at_notes(notes) do
    last_note = List.last(notes)
    id = last_note.id
    updated_at = NaiveDateTime.to_iso8601(last_note.updated_at)
    {id, updated_at}
  end
end

defmodule TdDd.DataStructures.StructureNoteWorkflowTest do
  use TdDd.DataCase

  alias TdDd.DataStructures
  alias TdDd.DataStructures.StructureNote
  alias TdDd.DataStructures.StructureNotesWorkflow

  describe "create" do
    test "create the first structure note with draft status and version 1" do
      %{id: data_structure_id} = data_structure = insert(:data_structure)

      create_attrs = %{
        "df_content" => %{"foo" => "bar"},
        "version" => 3
      }

      assert {:ok,
              %StructureNote{
                version: 1,
                status: :draft,
                df_content: %{
                  "foo" => "bar"
                },
                data_structure_id: ^data_structure_id
              }} = StructureNotesWorkflow.create(data_structure, create_attrs)
    end

    test "error when creating note with existing draft" do
      data_structure = insert(:data_structure)

      insert(:structure_note,
        status: :draft,
        data_structure: data_structure
      )

      create_attrs = %{"df_content" => %{"foo" => "bar"}}

      assert {:error, :conflict} = StructureNotesWorkflow.create(data_structure, create_attrs)
    end

    test "create a new structure note version when the previous has published status" do
      %{data_structure_id: data_structure_id, data_structure: data_structure} =
        insert(:structure_note, status: :published)

      assert {:ok,
              %StructureNote{
                version: 2,
                status: :draft,
                data_structure_id: ^data_structure_id
              }} = StructureNotesWorkflow.create(data_structure, %{})
    end

    test "when create a new version from a published note, the new draft must have the same df_content" do
      df_content = %{"foo" => "bar"}

      %{data_structure_id: data_structure_id, data_structure: data_structure} =
        insert(:structure_note, status: :published, df_content: df_content)

      create_attrs = %{"df_content" => %{"new" => "content"}}

      assert {:ok,
              %StructureNote{
                version: 2,
                status: :draft,
                df_content: ^df_content,
                data_structure_id: ^data_structure_id
              }} = StructureNotesWorkflow.create(data_structure, create_attrs)
    end
  end

  describe "update" do
    test "save content only for draft notes" do
      df_content = %{"new" => "content"}
      attrs = %{"df_content" => df_content}

      # updateable content statuses
      [:draft]
      |> Enum.each(fn status ->
        assert {:ok, %{df_content: ^df_content}} =
                 :structure_note
                 |> insert(status: status)
                 |> StructureNotesWorkflow.update(attrs)
      end)

      # not updateable content statuses
      [:pending_approval, :published, :deprecated, :versioned, :rejected]
      |> Enum.each(fn status ->
        assert {:error, _} =
                 :structure_note
                 |> insert(status: status)
                 |> StructureNotesWorkflow.update(attrs)
      end)
    end

    test "can only send a draft note to pending_approval" do
      attrs = %{"status" => "pending_approval"}

      # statuses that can be sent to pending_approval
      [:draft]
      |> Enum.each(fn status ->
        assert {:ok, %{status: :pending_approval}} =
                 :structure_note
                 |> insert(status: status)
                 |> StructureNotesWorkflow.update(attrs)
      end)

      # statuses that cant be sent to pending_approval
      [:pending_approval, :published, :deprecated, :versioned, :rejected]
      |> Enum.each(fn status ->
        assert {:error, _} =
                 :structure_note
                 |> insert(status: status)
                 |> StructureNotesWorkflow.update(attrs)
      end)
    end

    test "only pending_approval and draft notes can be published" do
      attrs = %{"status" => "published"}

      # statuses that can be sent to published
      [:pending_approval, :draft]
      |> Enum.each(fn status ->
        assert {:ok, %{status: :published}} =
                 :structure_note
                 |> insert(status: status)
                 |> StructureNotesWorkflow.update(attrs)
      end)

      # statuses that cant be sent to published
      [:published, :deprecated, :versioned, :rejected]
      |> Enum.each(fn status ->
        assert {:error, _} =
                 :structure_note
                 |> insert(status: status)
                 |> StructureNotesWorkflow.update(attrs)
      end)
    end

    test "published note is versioned when a new version is published" do
      %{id: data_structure_id} = insert(:data_structure)

      %{id: previous_structure_note_id} =
        insert(:structure_note,
          status: :published,
          version: 1,
          data_structure_id: data_structure_id
        )

      structure_note =
        insert(:structure_note,
          status: :pending_approval,
          version: 2,
          data_structure_id: data_structure_id
        )

      assert {:ok, %{status: :published}} =
               StructureNotesWorkflow.update(structure_note, %{"status" => "published"})

      assert %{status: :published} = DataStructures.get_structure_note!(structure_note.id)

      assert %{status: :versioned} =
               DataStructures.get_structure_note!(previous_structure_note_id)
    end

    test "can only reject a pending approval note" do
      attrs = %{"status" => "rejected"}

      [:pending_approval]
      |> Enum.each(fn status ->
        assert {:ok, %{status: :rejected}} =
                 :structure_note
                 |> insert(status: status)
                 |> StructureNotesWorkflow.update(attrs)
      end)

      # statuses that cant be sent to rejected
      [:draft, :published, :deprecated, :versioned]
      |> Enum.each(fn status ->
        assert {:error, _} =
                 :structure_note
                 |> insert(status: status)
                 |> StructureNotesWorkflow.update(attrs)
      end)
    end

    test "can only change to draft a rejected note" do
      attrs = %{"status" => "draft"}

      [:rejected]
      |> Enum.each(fn status ->
        assert {:ok, %{status: :draft}} =
                 :structure_note
                 |> insert(status: status)
                 |> StructureNotesWorkflow.update(attrs)
      end)

      # statuses that cant be sent to rejected
      [:pending_approval, :draft, :published, :deprecated, :versioned]
      |> Enum.each(fn status ->
        assert {:error, _} =
                 :structure_note
                 |> insert(status: status)
                 |> StructureNotesWorkflow.update(attrs)
      end)
    end

    test "only published notes without new versions can be deprecated" do
      attrs = %{"status" => "deprecated"}

      # statuses that cant be sent to rejected
      [:pending_approval, :draft, :versioned, :rejected, :deprecated]
      |> Enum.each(fn status ->
        assert {:error, _} =
                 :structure_note
                 |> insert(status: status)
                 |> StructureNotesWorkflow.update(attrs)
      end)

      assert {:ok, %{status: :deprecated}} =
               :structure_note
               |> insert(status: :published)
               |> StructureNotesWorkflow.update(attrs)

      data_structure = insert(:data_structure)

      structure_note =
        :structure_note
        |> insert(status: :published, data_structure_id: data_structure.id)

      StructureNotesWorkflow.create(data_structure, %{})
      assert {:error, _} = StructureNotesWorkflow.update(structure_note, attrs)
    end

    test "does not modify the content when the status changes" do
      initial_content = %{"initial" => "content"}

      statuses = [
        :draft,
        :pending_approval,
        :published,
        :deprecated,
        :rejected
      ]

      Enum.each(statuses, fn from_status ->
        statuses
        |> Enum.filter(fn status -> status != from_status end)
        |> Enum.each(fn to_status ->
          attrs = %{
            "status" => Atom.to_string(to_status),
            "df_content" => %{"new" => "content_#{from_status}_#{to_status}"}
          }

          update_output =
            :structure_note
            |> insert(status: from_status, df_content: initial_content)
            |> StructureNotesWorkflow.update(attrs)

          case update_output do
            {:ok, %{df_content: content}} -> assert initial_content == content
            {:error, _} -> assert true
          end
        end)
      end)
    end

    test "published note is versioned when a draft version is published" do
      %{id: data_structure_id} = insert(:data_structure)

      %{id: previous_structure_note_id} =
        insert(:structure_note,
          status: :published,
          version: 3,
          data_structure_id: data_structure_id
        )

      structure_note =
        insert(:structure_note,
          status: :draft,
          version: 4,
          data_structure_id: data_structure_id
        )

      assert {:ok, %{status: :published}} =
               StructureNotesWorkflow.update(structure_note, %{"status" => "published"})

      assert %{status: :published} = DataStructures.get_structure_note!(structure_note.id)

      assert %{status: :versioned} =
               DataStructures.get_structure_note!(previous_structure_note_id)
    end
  end

  describe "delete" do
    test "can only delete a rejected or draft note" do
      [:rejected, :draft]
      |> Enum.each(fn status ->
        assert {:ok, _} =
                 :structure_note
                 |> insert(status: status)
                 |> StructureNotesWorkflow.delete()
      end)

      [:pending_approval, :versioned, :published, :deprecated]
      |> Enum.each(fn status ->
        assert {:error, _} =
                 :structure_note
                 |> insert(status: status)
                 |> StructureNotesWorkflow.delete()
      end)
    end
  end
end

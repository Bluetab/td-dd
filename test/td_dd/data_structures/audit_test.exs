defmodule TdDd.DataStructures.AuditTest do
  use TdDd.DataCase

  alias TdCache.Redix
  alias TdCache.Redix.Stream
  alias TdDd.DataStructures.Audit
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.StructureNote
  alias TdDd.Repo

  @moduletag sandbox: :shared
  @stream TdCache.Audit.stream()
  @template_name "structure_note_test_template"

  setup do
    %{id: template_id, name: template_name} = CacheHelpers.insert_template(name: @template_name)
    CacheHelpers.insert_structure_type(name: template_name, template_id: template_id)
    start_supervised!(TdDd.Search.StructureEnricher)
    on_exit(fn -> Redix.del!(@stream) end)

    claims = build(:claims, role: "admin")
    data_structure = insert(:data_structure)

    data_structure_version =
      insert(:data_structure_version, data_structure: data_structure, type: @template_name)

    [claims: claims, data_structure_version: data_structure_version, type: @template_name]
  end

  describe "structure_note_updated/4" do
    test "publishes an event", %{
      data_structure_version: data_structure_version,
      claims: %{user_id: user_id}
    } do
      %{data_structure: %{id: data_structure_id} = data_structure} = data_structure_version

      %{id: note_id} =
        note =
        insert(:structure_note,
          data_structure: data_structure,
          df_content: %{"string" => "initial", "list" => "one", "foo" => "bar"},
          status: :draft,
          version: 1
        )

      changeset =
        StructureNote.changeset(note, %{
          df_content: %{"string" => "changed", "list" => "two", "foo" => "baz"}
        })

      assert {:ok, event_id} =
               Audit.structure_note_updated(
                 Repo,
                 %{structure_note: note, latest: data_structure_version},
                 changeset,
                 user_id
               )

      assert {:ok, [event]} = Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      user_id = "#{user_id}"
      resource_id = "#{note_id}"

      assert %{
               event: "structure_note_updated",
               payload: payload,
               resource_id: ^resource_id,
               resource_type: "data_structure_note",
               service: "td_dd",
               ts: _ts,
               user_id: ^user_id
             } = event

      assert %{
               "data_structure_id" => ^data_structure_id
             } = Jason.decode!(payload)
    end
  end

  describe "structure_note_status_updated/4" do
    test "publishes an event", %{
      data_structure_version: data_structure_version,
      claims: %{user_id: user_id}
    } do
      %{data_structure: %{id: data_structure_id} = data_structure} = data_structure_version

      %{id: note_id} =
        note =
        insert(:structure_note,
          data_structure: data_structure,
          df_content: %{"string" => "initial", "list" => "one", "foo" => "bar"},
          status: :draft
        )

      assert {:ok, event_id} =
               Audit.structure_note_status_updated(
                 Repo,
                 %{structure_note: note, latest: data_structure_version},
                 "pending_approval",
                 user_id
               )

      assert {:ok, [event]} = Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      user_id = "#{user_id}"
      resource_id = "#{note_id}"

      assert %{
               event: "structure_note_pending_approval",
               payload: payload,
               resource_id: ^resource_id,
               resource_type: "data_structure_note",
               service: "td_dd",
               ts: _ts,
               user_id: ^user_id
             } = event

      assert %{
               "data_structure_id" => ^data_structure_id
             } = Jason.decode!(payload)
    end
  end

  describe "structure_note_deleted/3" do
    test "publishes an event", %{
      data_structure_version: data_structure_version,
      claims: %{user_id: user_id}
    } do
      %{data_structure: %{id: data_structure_id} = data_structure} = data_structure_version

      %{id: note_id} =
        note =
        insert(:structure_note,
          data_structure: data_structure,
          df_content: %{"string" => "initial", "list" => "one", "foo" => "bar"},
          status: :published
        )

      assert {:ok, event_id} =
               Audit.structure_note_deleted(
                 Repo,
                 %{structure_note: note, latest: data_structure_version},
                 user_id
               )

      assert {:ok, [event]} = Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      user_id = "#{user_id}"
      resource_id = "#{note_id}"

      assert %{
               event: "structure_note_deleted",
               payload: payload,
               resource_id: ^resource_id,
               resource_type: "data_structure_note",
               service: "td_dd",
               ts: _ts,
               user_id: ^user_id
             } = event

      assert %{
               "data_structure_id" => ^data_structure_id
             } = Jason.decode!(payload)
    end
  end

  describe "data_structure_updated/4" do
    test "publishes an event", %{
      data_structure_version: data_structure_version,
      claims: %{user_id: user_id}
    } do
      %{data_structure: data_structure} = data_structure_version
      %{id: data_structure_id} = data_structure

      params = %{confidential: true}

      changeset = DataStructure.update_changeset(data_structure, params)

      assert {:ok, event_id} =
               Audit.data_structure_updated(
                 Repo,
                 %{data_structure: data_structure},
                 changeset,
                 user_id
               )

      assert {:ok, [event]} = Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      user_id = "#{user_id}"
      resource_id = "#{data_structure_id}"

      assert %{
               event: "data_structure_updated",
               payload: payload,
               resource_id: ^resource_id,
               resource_type: "data_structure",
               service: "td_dd",
               ts: _ts,
               user_id: ^user_id
             } = event

      assert %{
               "confidential" => true
             } = Jason.decode!(payload)
    end
  end

  describe "data_structure_deleted/3" do
    test "publishes an event", %{claims: %{user_id: user_id}} do
      %{id: data_structure_id} = data_structure = insert(:data_structure)

      assert {:ok, event_id} =
               Audit.data_structure_deleted(Repo, %{data_structure: data_structure}, user_id)

      assert {:ok, [event]} = Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      user_id = "#{user_id}"
      resource_id = "#{data_structure_id}"

      assert %{
               event: "data_structure_deleted",
               payload: "{}",
               resource_id: ^resource_id,
               resource_type: "data_structure",
               service: "td_dd",
               ts: _ts,
               user_id: ^user_id
             } = event
    end
  end
end

defmodule TdDd.DataStructures.AuditTest do
  use TdDd.DataCase

  alias TdCache.Redix
  alias TdCache.Redix.Stream
  alias TdCache.TemplateCache
  alias TdDd.DataStructures.Audit
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Repo

  @moduletag sandbox: :shared
  @stream TdCache.Audit.stream()

  setup_all do
    %{id: template_id, name: type} = template = build(:template)
    TemplateCache.put(template, publish: false)

    on_exit(fn ->
      TemplateCache.delete(template_id)
      Redix.del!(@stream)
    end)

    [type: type]
  end

  setup %{type: type} do
    start_supervised!(TdDd.Search.StructureEnricher)
    on_exit(fn -> Redix.del!(@stream) end)

    claims = build(:claims, role: "admin")
    %{data_structure: data_structure} = insert(:data_structure_version, type: type)
    [claims: claims, data_structure: data_structure]
  end

  describe "data_structure_updated/4" do
    test "publishes an event", %{data_structure: data_structure, claims: %{user_id: user_id}} do
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
               "confidential" => true,
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

defmodule TdDd.DataStructures.TagsTest do
  use TdDd.DataStructureCase

  alias TdCache.Redix.Stream
  alias TdCore.Search.IndexWorkerMock
  alias TdDd.DataStructures.Tags
  alias TdDd.DataStructures.Tags.StructureTag
  alias TdDd.DataStructures.Tags.Tag
  alias TdDd.Repo

  @moduletag sandbox: :shared
  @stream TdCache.Audit.stream()

  setup do
    IndexWorkerMock.clear()

    :ok
  end

  describe "Tags.list_tags/0" do
    test "returns all data structure tags" do
      tag = insert(:tag)
      assert Tags.list_tags() == [tag]
    end
  end

  describe "Tags.list_tags/1" do
    setup do
      now = NaiveDateTime.local_now()
      five_days_ago = NaiveDateTime.add(now, -5, :day)
      three_days_ago = NaiveDateTime.add(now, -3, :day)
      one_day_ago = NaiveDateTime.add(now, -1, :day)

      %{id: tag_id_1} = insert(:tag, updated_at: now)
      %{id: tag_id_2} = insert(:tag, updated_at: five_days_ago)
      %{id: tag_id_3} = insert(:tag, updated_at: three_days_ago)
      %{id: tag_id_4} = insert(:tag, updated_at: one_day_ago)

      {:ok,
       tag_ids: [tag_id_1, tag_id_2, tag_id_3, tag_id_4],
       four_days_ago: NaiveDateTime.add(now, -4, :day)}
    end

    test "returns all data structure tags with structure count" do
      %{tag: %{id: id, name: name}} = insert(:structure_tag)

      assert tags = [_ | _] = Tags.list_tags(structure_count: true)

      assert tags |> Enum.find(&(&1.id == id)) |> Map.take([:id, :name, :structure_count]) == %{
               id: id,
               name: name,
               structure_count: 1
             }
    end

    test("with no params returns all items", %{
      tag_ids: [tag_id_1, tag_id_2, tag_id_3, tag_id_4]
    }) do
      assert [tag_id_1, tag_id_2, tag_id_3, tag_id_4] ==
               %{}
               |> Tags.list_tags()
               |> Enum.map(&Map.get(&1, :id))
    end

    @tag authentication: [role: "service"]
    test("with since param returns updated_at after date", %{
      tag_ids: [tag_id_1, _tag_id_2, tag_id_3, tag_id_4],
      four_days_ago: four_days_ago
    }) do
      params = %{since: NaiveDateTime.to_string(four_days_ago)}

      assert [tag_id_3, tag_id_4, tag_id_1] ==
               params
               |> Tags.list_tags()
               |> Enum.map(&Map.get(&1, :id))
    end

    @tag authentication: [role: "service"]
    test("with min_id param returns grater or equal ids", %{
      tag_ids: [_tag_id_1, _tag_id_2, tag_id_3, tag_id_4]
    }) do
      params = %{min_id: tag_id_3}

      assert [tag_id_3, tag_id_4] ==
               params
               |> Tags.list_tags()
               |> Enum.map(&Map.get(&1, :id))
    end

    @tag authentication: [role: "service"]
    test("with since, min_id and size params returns filtered results", %{
      tag_ids: [_tag_id_1, tag_id_2, tag_id_3, _tag_id_4],
      four_days_ago: four_days_ago
    }) do
      params = %{
        since: NaiveDateTime.to_string(four_days_ago),
        min_id: tag_id_2,
        size: 1
      }

      assert [tag_id_3] ==
               params
               |> Tags.list_tags()
               |> Enum.map(&Map.get(&1, :id))
    end

    @tag authentication: [role: "service"]
    test("not allowed param will be omited", %{
      tag_ids: [tag_id_1, tag_id_2, tag_id_3, tag_id_4]
    }) do
      params = %{anything: false}

      assert [tag_id_1, tag_id_2, tag_id_3, tag_id_4] ==
               params
               |> Tags.list_tags()
               |> Enum.map(&Map.get(&1, :id))
    end
  end

  describe "Tags.get_tag/1" do
    test "returns the tag with given id" do
      %{id: id} = tag = insert(:tag)
      assert Tags.get_tag(id: id) == tag
    end
  end

  describe "Tags.create_tag/1" do
    test "with valid data creates a data structure tag" do
      %{name: name} = build(:tag)

      assert {:ok, %Tag{} = tag} = Tags.create_tag(%{name: name})

      assert %{name: ^name} = tag
    end

    test "with invalid data returns error changeset" do
      assert {:error, %{valid?: false, errors: errors}} = Tags.create_tag(%{name: nil})

      assert {_, [validation: :required]} = errors[:name]
    end
  end

  describe "Tags.update_tag/2" do
    test "with valid data updates the tag" do
      tag = insert(:tag)
      %{name: name} = build(:tag)

      assert {:ok, %Tag{} = tag} = Tags.update_tag(tag, %{name: name})

      assert %{name: ^name} = tag
    end

    test "with invalid data returns error changeset" do
      tag = insert(:tag)

      assert {:error, %{valid?: false, errors: errors}} = Tags.update_tag(tag, %{name: nil})

      assert {_, [validation: :required]} = errors[:name]
    end
  end

  describe "Tags.delete_tag/1" do
    test "deletes the data structure tag" do
      %{id: id} = tag = insert(:tag)

      assert {:ok, %Tag{__meta__: %{state: :deleted}}} = Tags.delete_tag(tag)

      refute Repo.get(Tag, id)
    end
  end

  describe "Tags.tags/1" do
    test "gets a list of links between a structure and its tags" do
      [%{data_structure: structure, data_structure_id: data_structure_id}] =
        create_hierarchy(["foo"])

      tag = %{id: tag_id, name: name} = insert(:tag)

      %{id: link_id, comment: comment} =
        insert(:structure_tag, data_structure: structure, tag: tag)

      assert [
               %{
                 id: ^link_id,
                 data_structure: %{id: ^data_structure_id},
                 tag: %{id: ^tag_id, name: ^name},
                 comment: ^comment
               }
             ] = Tags.tags(structure)
    end

    test "includes inherited tags from nearest ancestor" do
      %{id: tag_id} = insert(:tag)

      [foo, bar, baz, xyzzy] = create_hierarchy(["foo", "bar", "baz", "xyzzy"])

      assert Tags.tags(xyzzy) == []

      %{id: id0} = insert(:structure_tag, data_structure_id: foo.data_structure_id)

      assert [%{id: ^id0, inherited: false}] = Tags.tags(foo)

      assert Tags.tags(xyzzy) == []

      %{id: id1} =
        insert(:structure_tag,
          data_structure_id: foo.data_structure_id,
          tag_id: tag_id,
          inherit: true
        )

      assert [%{id: ^id1, inherited: true}] = Tags.tags(xyzzy)

      insert(:structure_tag,
        data_structure_id: bar.data_structure_id,
        tag_id: tag_id
      )

      assert [%{id: ^id1, inherited: true}] = Tags.tags(xyzzy)

      %{id: id2} =
        insert(:structure_tag,
          data_structure_id: baz.data_structure_id,
          tag_id: tag_id,
          inherit: true
        )

      assert [%{id: ^id2, inherited: true}] = Tags.tags(xyzzy)

      %{id: id3} =
        insert(:structure_tag,
          data_structure_id: xyzzy.data_structure_id,
          tag_id: tag_id
        )

      assert [%{id: ^id3, inherited: false}] = Tags.tags(xyzzy)

      insert(:structure_tag, data_structure_id: baz.data_structure_id, inherit: true)

      assert [_, _] = Tags.tags(xyzzy)
    end
  end

  describe "Tags.tag_structure/3" do
    setup do
      start_supervised!(TdDd.Search.StructureEnricher)

      [claims: build(:claims)]
    end

    test "links tag to a given structure", %{claims: claims} do
      IndexWorkerMock.clear()
      %{comment: comment} = build(:structure_tag)

      structure =
        %{id: data_structure_id, external_id: external_id, updated_at: updated_at_before} =
        insert(:data_structure)

      %{name: version_name} = insert(:data_structure_version, data_structure: structure)

      tag = %{id: tag_id, name: tag_name, description: _tag_description} = insert(:tag)

      params = %{comment: comment}

      {:ok,
       %{
         audit: event_id,
         structure_tag: %{
           comment: ^comment,
           data_structure: %{id: ^data_structure_id},
           tag: %{id: ^tag_id}
         },
         update_at_change: %{updated_at: updated_at_after}
       }} = Tags.tag_structure(structure, tag, params, claims)

      assert {:ok, [%{id: ^event_id, payload: payload}]} =
               Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      assert updated_at_after != updated_at_before

      assert %{
               "comment" => ^comment,
               "tag" => ^tag_name,
               "resource" => %{
                 "external_id" => ^external_id,
                 "name" => ^version_name,
                 "path" => []
               }
             } = Jason.decode!(payload)

      assert [{:reindex, :structures, _}] = IndexWorkerMock.calls()
    end

    test "updates structure tag when it already exists", %{claims: claims} do
      %{comment: comment} = build(:structure_tag)

      structure =
        %{id: data_structure_id, external_id: external_id, updated_at: updated_at_before} =
        insert(:data_structure)

      tag = %{id: tag_id, name: tag_name} = insert(:tag)

      %{name: version_name} = insert(:data_structure_version, data_structure: structure)

      insert(:structure_tag, data_structure: structure, tag: tag, comment: "foo")

      params = %{comment: comment}

      {:ok,
       %{
         audit: event_id,
         structure_tag: %{
           comment: ^comment,
           data_structure: %{id: ^data_structure_id},
           tag: %{id: ^tag_id}
         },
         update_at_change: %{updated_at: updated_at_after}
       }} = Tags.tag_structure(structure, tag, params, claims)

      assert {:ok, [%{id: ^event_id, payload: payload}]} =
               Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      assert updated_at_after != updated_at_before

      assert %{
               "comment" => ^comment,
               "tag" => ^tag_name,
               "resource" => %{
                 "external_id" => ^external_id,
                 "name" => ^version_name,
                 "path" => []
               }
             } = Jason.decode!(payload)
    end

    test "gets error when comment is invalid", %{claims: claims} do
      structure = insert(:data_structure)
      tag = insert(:tag)

      params = %{comment: String.duplicate("foo", 334)}

      assert {:error, _,
              %{
                errors: [
                  comment: {_, [count: 1000, validation: :length, kind: :max, type: :string]}
                ],
                valid?: false
              }, _} = Tags.tag_structure(structure, tag, params, claims)
    end
  end

  describe "Tags.untag_structure/2" do
    setup do
      start_supervised!(TdDd.Search.StructureEnricher)

      [claims: build(:claims)]
    end

    test "deletes structure tag", %{claims: claims} do
      IndexWorkerMock.clear()

      structure =
        %{id: data_structure_id, external_id: external_id, updated_at: updated_at_before} =
        insert(:data_structure)

      tag = %{id: tag_id, name: tag_name} = insert(:tag)

      %{name: version_name} = insert(:data_structure_version, data_structure: structure)

      %{comment: comment} = insert(:structure_tag, data_structure: structure, tag: tag)

      assert {:ok,
              %{
                audit: event_id,
                structure_tag: %{
                  data_structure_id: ^data_structure_id,
                  tag_id: ^tag_id,
                  updated_at: updated_at_after
                }
              }} = Tags.untag_structure(structure, tag, claims)

      assert {:ok, [%{id: ^event_id, payload: payload}]} =
               Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      assert updated_at_after != updated_at_before

      assert %{
               "comment" => ^comment,
               "tag" => ^tag_name,
               "resource" => %{
                 "external_id" => ^external_id,
                 "name" => ^version_name,
                 "path" => []
               }
             } = Jason.decode!(payload)

      refute Repo.get_by(StructureTag,
               tag_id: tag_id,
               data_structure_id: data_structure_id
             )

      assert [{:reindex, :structures, _}] = IndexWorkerMock.calls()
    end

    test "not_found if structure tag does not exist", %{claims: claims} do
      structure = %{id: data_structure_id} = insert(:data_structure)
      tag = %{id: tag_id} = insert(:tag)

      assert {:error, :not_found} = Tags.untag_structure(structure, tag, claims)

      refute Repo.get_by(StructureTag,
               tag_id: tag_id,
               data_structure_id: data_structure_id
             )
    end
  end
end

defmodule TdDd.DataStructures.TagsTest do
  use TdDd.DataStructureCase

  alias TdCache.Redix.Stream
  alias TdDd.DataStructures.DataStructuresTags
  alias TdDd.DataStructures.DataStructureTag
  alias TdDd.DataStructures.Tags
  alias TdDd.Repo

  @moduletag sandbox: :shared
  @stream TdCache.Audit.stream()

  describe "list_data_structure_tags/0" do
    test "returns all data structure tags" do
      data_structure_tag = insert(:data_structure_tag)
      assert Tags.list_data_structure_tags() == [data_structure_tag]
    end
  end

  describe "list_data_structure_tags/1" do
    test "returns all data structure tags with structure count" do
      %{data_structure_tag: %{id: id, name: name}} = insert(:data_structures_tags)

      assert [%{id: ^id, name: ^name, structure_count: 1}] =
               Tags.list_data_structure_tags(structure_count: true)
    end
  end

  describe "get_data_structure_tag/1" do
    test "returns the data_structure_tag with given id" do
      %{id: id} = data_structure_tag = insert(:data_structure_tag)
      assert Tags.get_data_structure_tag(id: id) == data_structure_tag
    end
  end

  describe "create_data_structure_tag/1" do
    test "with valid data creates a data structure tag" do
      %{name: name} = build(:data_structure_tag)

      assert {:ok, %DataStructureTag{} = data_structure_tag} =
               Tags.create_data_structure_tag(%{name: name})

      assert %{name: ^name} = data_structure_tag
    end

    test "with invalid data returns error changeset" do
      assert {:error, %{valid?: false, errors: errors}} =
               Tags.create_data_structure_tag(%{name: nil})

      assert {_, [validation: :required]} = errors[:name]
    end
  end

  describe "update_data_structure_tag/2" do
    test "with valid data updates the data_structure_tag" do
      data_structure_tag = insert(:data_structure_tag)
      %{name: name} = build(:data_structure_tag)

      assert {:ok, %DataStructureTag{} = data_structure_tag} =
               Tags.update_data_structure_tag(data_structure_tag, %{name: name})

      assert %{name: ^name} = data_structure_tag
    end

    test "with invalid data returns error changeset" do
      data_structure_tag = insert(:data_structure_tag)

      assert {:error, %{valid?: false, errors: errors}} =
               Tags.update_data_structure_tag(data_structure_tag, %{name: nil})

      assert {_, [validation: :required]} = errors[:name]
    end
  end

  describe "delete_data_structure_tag/1" do
    test "deletes the data structure tag" do
      %{id: id} = data_structure_tag = insert(:data_structure_tag)

      assert {:ok, %DataStructureTag{__meta__: %{state: :deleted}}} =
               Tags.delete_data_structure_tag(data_structure_tag)

      refute Repo.get(DataStructureTag, id)
    end
  end

  describe "tags/1" do
    test "gets a list of links between a structure and its tags" do
      [%{data_structure: structure, data_structure_id: data_structure_id}] =
        create_hierarchy(["foo"])

      tag = %{id: data_structure_tag_id, name: name} = insert(:data_structure_tag)

      %{id: link_id, comment: comment} =
        insert(:data_structures_tags, data_structure: structure, data_structure_tag: tag)

      assert [
               %{
                 id: ^link_id,
                 data_structure: %{id: ^data_structure_id},
                 data_structure_tag: %{id: ^data_structure_tag_id, name: ^name},
                 comment: ^comment
               }
             ] = Tags.tags(structure)
    end

    test "includes inherited tags" do
      %{id: tag_id} = insert(:data_structure_tag)

      [foo, bar, baz, xyzzy] = create_hierarchy(["foo", "bar", "baz", "xyzzy"])

      assert Tags.tags(xyzzy) == []

      insert(:data_structures_tags, data_structure_id: foo.data_structure_id)

      assert Tags.tags(xyzzy) == []

      %{id: id1} =
        insert(:data_structures_tags,
          data_structure_id: foo.data_structure_id,
          data_structure_tag_id: tag_id,
          inherit: true
        )

      assert [%{id: ^id1}] = Tags.tags(xyzzy)

      insert(:data_structures_tags,
        data_structure_id: bar.data_structure_id,
        data_structure_tag_id: tag_id
      )

      assert [%{id: ^id1}] = Tags.tags(xyzzy)

      %{id: id2} =
        insert(:data_structures_tags,
          data_structure_id: baz.data_structure_id,
          data_structure_tag_id: tag_id,
          inherit: true
        )

      assert [%{id: ^id2}] = Tags.tags(xyzzy)

      %{id: id3} =
        insert(:data_structures_tags,
          data_structure_id: xyzzy.data_structure_id,
          data_structure_tag_id: tag_id
        )

      assert [%{id: ^id3}] = Tags.tags(xyzzy)

      insert(:data_structures_tags, data_structure_id: baz.data_structure_id, inherit: true)

      assert [_, _] = Tags.tags(xyzzy)
    end
  end

  describe "link_tag/3" do
    setup do
      start_supervised!(TdDd.Search.StructureEnricher)
      [claims: build(:claims)]
    end

    test "links tag to a given structure", %{claims: claims} do
      %{comment: comment} = build(:data_structures_tags)
      structure = %{id: data_structure_id, external_id: external_id} = insert(:data_structure)
      %{name: version_name} = insert(:data_structure_version, data_structure: structure)

      tag =
        %{
          id: tag_id,
          name: tag_name,
          description: _tag_description
        } = insert(:data_structure_tag)

      params = %{comment: comment}

      {:ok,
       %{
         audit: event_id,
         linked_tag: %{
           comment: ^comment,
           data_structure: %{id: ^data_structure_id},
           data_structure_tag: %{id: ^tag_id}
         }
       }} = Tags.link_tag(structure, tag, params, claims)

      assert {:ok, [%{id: ^event_id, payload: payload}]} =
               Stream.range(:redix, @stream, event_id, event_id, transform: :range)

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

    test "updates link information when it already exists", %{claims: claims} do
      %{comment: comment} = build(:data_structures_tags)
      structure = %{id: data_structure_id, external_id: external_id} = insert(:data_structure)

      tag =
        %{
          id: tag_id,
          name: tag_name,
          description: _tag_description
        } = insert(:data_structure_tag)

      %{name: version_name} = insert(:data_structure_version, data_structure: structure)

      insert(:data_structures_tags,
        data_structure_tag: tag,
        data_structure: structure,
        comment: "foo"
      )

      params = %{comment: comment}

      {:ok,
       %{
         audit: event_id,
         linked_tag: %{
           comment: ^comment,
           data_structure: %{id: ^data_structure_id},
           data_structure_tag: %{id: ^tag_id}
         }
       }} = Tags.link_tag(structure, tag, params, claims)

      assert {:ok, [%{id: ^event_id, payload: payload}]} =
               Stream.range(:redix, @stream, event_id, event_id, transform: :range)

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
      tag = insert(:data_structure_tag)

      params = %{comment: String.duplicate("foo", 334)}

      assert {:error, _,
              %{
                errors: [
                  comment: {_, [count: 1000, validation: :length, kind: :max, type: :string]}
                ],
                valid?: false
              }, _} = Tags.link_tag(structure, tag, params, claims)
    end
  end

  describe "delete_link_tag/2" do
    setup do
      start_supervised!(TdDd.Search.StructureEnricher)
      [claims: build(:claims)]
    end

    test "deletes link between tag and structure", %{claims: claims} do
      structure = %{id: data_structure_id, external_id: external_id} = insert(:data_structure)

      tag = %{id: data_structure_tag_id, name: tag_name} = insert(:data_structure_tag)

      %{name: version_name} = insert(:data_structure_version, data_structure: structure)

      %{comment: comment} =
        insert(:data_structures_tags, data_structure: structure, data_structure_tag: tag)

      assert {:ok,
              %{
                audit: event_id,
                deleted_link_tag: %{
                  data_structure_id: ^data_structure_id,
                  data_structure_tag_id: ^data_structure_tag_id
                }
              }} = Tags.delete_link_tag(structure, tag, claims)

      assert {:ok, [%{id: ^event_id, payload: payload}]} =
               Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      assert %{
               "comment" => ^comment,
               "tag" => ^tag_name,
               "resource" => %{
                 "external_id" => ^external_id,
                 "name" => ^version_name,
                 "path" => []
               }
             } = Jason.decode!(payload)

      refute Repo.get_by(DataStructuresTags,
               data_structure_tag_id: data_structure_tag_id,
               data_structure_id: data_structure_id
             )
    end

    test "not_found if link does not exist", %{claims: claims} do
      structure = %{id: data_structure_id} = insert(:data_structure)
      tag = %{id: data_structure_tag_id} = insert(:data_structure_tag)

      assert {:error, :not_found} = Tags.delete_link_tag(structure, tag, claims)

      refute Repo.get_by(DataStructuresTags,
               data_structure_tag_id: data_structure_tag_id,
               data_structure_id: data_structure_id
             )
    end
  end
end

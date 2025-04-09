defmodule TdDd.DataStructureLinksTest do
  use TdDd.DataStructureCase

  alias TdDd.DataStructures.DataStructureLink
  alias TdDd.DataStructures.DataStructureLinks
  alias TdDd.DataStructures.Label

  describe "links/1" do
    test "returns all links for a given data structure" do
      source = insert(:data_structure)
      target = insert(:data_structure)

      insert(:data_structure_link,
        source_id: source.id,
        target_id: target.id,
        labels: [insert(:label), insert(:label)]
      )

      links = DataStructureLinks.links(source)
      assert length(links) == 1
      assert Enum.any?(links, &(&1.source_id == source.id and &1.target_id == target.id))
    end
  end

  describe "create_and_audit/2" do
    test "creates a link and audits the action" do
      %{id: source_id} = insert(:data_structure)
      %{id: target_id} = insert(:data_structure)
      user_id = 1

      changeset =
        DataStructureLink.changeset_from_ids(%{source_id: source_id, target_id: target_id})

      assert {:ok, %{data_structure_link: link}} =
               DataStructureLinks.create_and_audit(changeset, user_id)

      assert link.source_id == source_id
      assert link.target_id == target_id
    end
  end

  describe "delete_and_audit/2" do
    test "deletes a link and audits the action" do
      %{id: source_id} = insert(:data_structure)
      %{id: target_id} = insert(:data_structure)

      link =
        insert(:data_structure_link,
          source_id: source_id,
          target_id: target_id,
          labels: [insert(:label), insert(:label)]
        )

      user_id = 1

      assert {:ok, %{data_structure_link: _deleted_link}} =
               DataStructureLinks.delete_and_audit(link, user_id)

      refute Repo.get(DataStructureLink, link.id)
    end
  end

  describe "bulk_load/1" do
    test "loads multiple links in bulk" do
      %{external_id: source_external_id} = insert(:data_structure)
      %{external_id: target_external_id} = insert(:data_structure)

      links = [%{source_external_id: source_external_id, target_external_id: target_external_id}]
      assert {:ok, result} = DataStructureLinks.bulk_load(links)

      assert length(MapSet.to_list(result.inserted)) == 1

      assert Enum.any?(
               MapSet.to_list(result.inserted),
               &(&1.source_external_id == source_external_id)
             )
    end
  end

  describe "search/1" do
    test "returns links matching the search criteria" do
      for i <- 1..8 do
        insert(:data_structure_link,
          source: insert(:data_structure),
          target: insert(:data_structure),
          updated_at: "2025-0#{i}-01 15:28:34.254705Z",
          labels: [insert(:label), insert(:label)]
        )
      end

      {:ok, %{data_structure_links: links}} =
        DataStructureLinks.search(%{"since" => "2025-01-01 15:28:34.254705Z", "size" => 2})

      assert length(links) == 2

      assert [_] =
               Enum.filter(
                 links,
                 &(&1.updated_at == ~U[2025-01-01 15:28:34.254705Z])
               )

      assert [_] =
               Enum.filter(
                 links,
                 &(&1.updated_at == ~U[2025-02-01 15:28:34.254705Z])
               )
    end

    test "returns no links if no matches are found" do
      for i <- 1..8 do
        insert(:data_structure_link,
          source: insert(:data_structure),
          target: insert(:data_structure),
          updated_at: "2025-0#{i}-01 15:28:34.254705Z",
          labels: [insert(:label), insert(:label)]
        )
      end

      {:ok, %{data_structure_links: links}} =
        DataStructureLinks.search(%{"since" => "2026-01-01 15:28:34.254705Z"})

      assert Enum.empty?(links)
    end

    test "applies pagination correctly" do
      for i <- 1..8 do
        insert(:data_structure_link,
          source: insert(:data_structure),
          target: insert(:data_structure),
          updated_at: "2025-0#{i}-01 15:28:34.254705Z",
          labels: [insert(:label), insert(:label)]
        )
      end

      {:ok, %{data_structure_links: links, scroll_id: scroll_id}} =
        DataStructureLinks.search(%{"size" => 2})

      assert length(links) == 2
      assert scroll_id != nil
    end

    test "handles invalid parameters gracefully" do
      assert {:error, _error} = DataStructureLinks.search(%{"invalid_param" => "value"})
    end

    test "returns links sorted by updated_at and id" do
      %{id: link_id_1} =
        insert(:data_structure_link,
          source: insert(:data_structure),
          target: insert(:data_structure),
          updated_at: "2025-05-04 15:28:34.254705Z",
          labels: [insert(:label), insert(:label)]
        )

      %{id: link_id_2} =
        insert(:data_structure_link,
          source: insert(:data_structure),
          target: insert(:data_structure),
          updated_at: "2025-04-04 15:28:34.254705Z",
          labels: [insert(:label), insert(:label)]
        )

      %{id: link_id_3} =
        insert(:data_structure_link,
          source: insert(:data_structure),
          target: insert(:data_structure),
          updated_at: "2025-04-04 15:28:34.254705Z",
          labels: [insert(:label), insert(:label)]
        )

      {:ok,
       %{
         data_structure_links: [
           %{id: search_link_id_2},
           %{id: search_link_id_3},
           %{id: search_link_id_1}
         ]
       }} =
        DataStructureLinks.search(%{})

      assert [^link_id_2, ^link_id_3, ^link_id_1] = [
               search_link_id_2,
               search_link_id_3,
               search_link_id_1
             ]
    end
  end

  describe "validate_params/1" do
    test "validates link parameters" do
      %{id: source_id} = insert(:data_structure)
      %{id: target_id} = insert(:data_structure)

      assert {:ok, _changeset} =
               DataStructureLinks.validate_params(%{source_id: source_id, target_id: target_id})

      assert {:error, _changeset} =
               DataStructureLinks.validate_params(%{source_id: nil, target_id: target_id})
    end
  end

  describe "labels" do
    test "creates a label" do
      assert {:ok, %Label{name: "test_label"}} =
               DataStructureLinks.create_label(%{name: "test_label"})
    end

    test "lists all labels" do
      insert(:label, name: "label1")
      insert(:label, name: "label2")

      labels = DataStructureLinks.list_labels()
      assert length(labels) == 2
    end

    test "gets a label by id" do
      %{id: label_id} = insert(:label, name: "label1")
      assert %Label{id: ^label_id} = DataStructureLinks.get_label_by(%{"id" => label_id})
    end

    test "gets a label by name" do
      %{name: label_name} = insert(:label, name: "label1")
      assert %Label{name: ^label_name} = DataStructureLinks.get_label_by(%{"name" => label_name})
    end

    test "deletes a label" do
      label = insert(:label, name: "label1")
      assert {:ok, _} = DataStructureLinks.delete_label(label)
      refute Repo.get(Label, label.id)
    end
  end
end

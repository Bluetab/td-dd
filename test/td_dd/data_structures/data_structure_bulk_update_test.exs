defmodule TdDd.DataStructureBulkUpdateTest do
  use TdDd.DataCase

  alias TdCache.TemplateCache
  alias TdDd.DataStructure.BulkUpdate
  alias TdDd.DataStructures
  alias TdDdWeb.ApiServices.MockTdAuthService

  setup_all do
    start_supervised(MockTdAuthService)
    :ok
  end

  describe "business_concepts_bulk_update" do
    test "update_all/3 update all data structure with valid data" do
      user = build(:user)
      insert(:system, id: 1)

      structure1 = insert(:data_structure, external_id: "Structure1")
      _structure_version1 = insert(:data_structure_version, data_structure_id: structure1.id)
      structure2 = insert(:data_structure, external_id: "Structure2")
      _structure_version2 = insert(:data_structure_version, data_structure_id: structure2.id)

      TemplateCache.put(%{
        name: "Table",
        content: [
          %{
            "name" => "Field1",
            "type" => "string",
            "group" => "Multiple Group",
            "label" => "Multiple 1",
            "values" => nil,
            "cardinality" => "1"
          },
          %{
            "name" => "Field2",
            "type" => "string",
            "group" => "Multiple Group",
            "label" => "Multiple 1",
            "values" => nil,
            "cardinality" => "1"
          }
        ],
        scope: "test",
        label: "template_label",
        id: "999"
      })

      params = %{
        "df_content" => %{
          "Field1" => "hola soy field 1",
          "Field2" => "hola soy field 2"
        }
      }

      assert {:ok, ds_ids} = BulkUpdate.update_all(user, [structure1, structure2], params)
      assert length(ds_ids) == 2

      assert DataStructures.get_latest_version(structure1.id).data_structure.df_content == %{
               "Field1" => "hola soy field 1",
               "Field2" => "hola soy field 2"
             }

      assert DataStructures.get_latest_version(structure2.id).data_structure.df_content == %{
               "Field1" => "hola soy field 1",
               "Field2" => "hola soy field 2"
             }
    end

    test "update_all/3 update all data structure with invalid data: structure type -> Schema" do
      user = build(:user)
      insert(:system, id: 1)

      structure1 = insert(:data_structure, external_id: "Structure1")
      _structure_version1 = insert(:data_structure_version, data_structure_id: structure1.id)
      structure_no_table = insert(:data_structure, external_id: "Structure3")
      _structure_version_no_table =
        insert(:data_structure_version_no_table, data_structure_id: structure_no_table.id)

      TemplateCache.put(%{
        name: "Table",
        content: [
          %{
            "name" => "Field1",
            "type" => "string",
            "group" => "Multiple Group",
            "label" => "Multiple 1",
            "values" => nil,
            "cardinality" => "1"
          },
          %{
            "name" => "Field2",
            "type" => "string",
            "group" => "Multiple Group",
            "label" => "Multiple 1",
            "values" => nil,
            "cardinality" => "1"
          }
        ],
        scope: "test",
        label: "template_label",
        id: "999"
      })

      params = %{
        "df_content" => %{
          "Field1" => "hola soy field 1",
          "Field2" => "hola soy field 2"
        }
      }

      assert {:error, "Invalid template"} = BulkUpdate.update_all(user, [structure1, structure_no_table], params)
    end
  end

  test "update_all/3 update only updated fields" do
    user = build(:user)
    insert(:system, id: 1)

    structure1 = insert(:data_structure, external_id: "Structure1")
    _structure_version1 = insert(:data_structure_version, data_structure_id: structure1.id)
    structure2 = insert(:data_structure, external_id: "Structure2")
    _structure_version2 = insert(:data_structure_version, data_structure_id: structure2.id)

    TemplateCache.put(%{
      name: "Table",
      content: [
        %{
          "name" => "Field1",
          "type" => "string",
          "group" => "Multiple Group",
          "label" => "Multiple 1",
          "values" => nil,
          "cardinality" => "1"
        },
        %{
          "name" => "Field2",
          "type" => "string",
          "group" => "Multiple Group",
          "label" => "Multiple 1",
          "values" => nil,
          "cardinality" => "1"
        }
      ],
      scope: "test",
      label: "template_label",
      id: "999"
    })

    params = %{
      "df_content" => %{
        "Field1" => "hola soy field 1",
        "Field2" => "hola soy field 2"
      }
    }

    assert {:ok, ds_ids} = BulkUpdate.update_all(user, [structure1, structure2], params)
    assert length(ds_ids) == 2

    assert DataStructures.get_latest_version(structure1.id).data_structure.df_content == %{
             "Field1" => "hola soy field 1",
             "Field2" => "hola soy field 2"
           }

    assert DataStructures.get_latest_version(structure2.id).data_structure.df_content == %{
             "Field1" => "hola soy field 1",
             "Field2" => "hola soy field 2"
           }

    params = %{
      "df_content" => %{
        "Field1" => "hola solo actualiza field 1",
      }
    }

    assert {:ok, ds_ids} = BulkUpdate.update_all(user, [structure1, structure2], params)
    assert length(ds_ids) == 2

    assert DataStructures.get_latest_version(structure1.id).data_structure.df_content == %{
             "Field1" => "hola solo actualiza field 1",
             "Field2" => "hola soy field 2"
           }

    assert DataStructures.get_latest_version(structure2.id).data_structure.df_content == %{
             "Field1" => "hola solo actualiza field 1",
             "Field2" => "hola soy field 2"
           }
  end
end

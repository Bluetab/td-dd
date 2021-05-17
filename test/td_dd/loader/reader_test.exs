defmodule TdDd.Loader.ReaderTest do
  use TdDd.DataCase

  alias TdDd.Loader.Reader

  describe "Reader.enrich_data_structures!/3" do
    setup do
      [domain: CacheHelpers.insert_domain()]
    end

    test "casts and puts system_id and domain_id", %{
      domain: %{id: domain_id, external_id: domain_external_id}
    } do
      system = %{id: 42}

      data_structures = [
        %{
          "external_id" => "foo",
          "group" => "group42",
          "metadata" => %{"meta1" => "awesome"},
          "mutable_metadata" => %{"wtf" => ["why"]},
          "name" => "amazing test structure 1",
          "type" => "BUCKET"
        }
      ]

      assert [result] =
               Reader.enrich_data_structures!(system, domain_external_id, data_structures)

      assert %{
               domain_id: ^domain_id,
               system_id: 42,
               external_id: "foo",
               group: "group42",
               metadata: %{"meta1" => "awesome"},
               mutable_metadata: %{"wtf" => ["why"]},
               name: "amazing test structure 1",
               type: "BUCKET"
             } = result
    end

    test "throws exception when data is not valid", %{domain: %{external_id: domain_external_id}} do
      system = %{id: 42}
      data_structures = [%{}]

      assert_raise CaseClauseError, ~r/.*valid\?: false*/, fn ->
        Reader.enrich_data_structures!(system, domain_external_id, data_structures)
      end
    end
  end

  describe "Reader.cast_data_structure_relations!/3" do
    test "casts relations" do
      relations = [
        %{
          "parent_external_id" => "foo",
          "child_external_id" => "bar",
          "relation_type_name" => "baz"
        }
      ]

      assert [result] = Reader.cast_data_structure_relations!(relations)

      assert %{
               parent_external_id: "foo",
               child_external_id: "bar",
               relation_type_name: "baz"
             } = result
    end

    test "throws exception when data is not valid" do
      relations = [%{}]

      assert_raise CaseClauseError, ~r/.*valid\?: false*/, fn ->
        Reader.cast_data_structure_relations!(relations)
      end
    end
  end
end

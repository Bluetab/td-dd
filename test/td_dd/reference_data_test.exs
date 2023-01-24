defmodule TdDd.ReferenceDataTest do
  use TdDd.DataCase

  alias TdDd.ReferenceData

  describe "ReferenceData.get!/1" do
    test "returns a dataset by id" do
      %{id: id, name: name} = insert(:reference_dataset)
      assert %{id: ^id, name: ^name} = ReferenceData.get!(id)
    end
  end

  describe "ReferenceData.create/1" do
    test "creates a dataset with valid data" do
      assert {:ok, dataset} =
               ReferenceData.create(%{
                 name: "Countries",
                 path: "test/fixtures/reference_data/dataset1.csv",
                 domain_ids: [1]
               })

      assert %{name: "Countries", headers: headers, rows: rows, row_count: 5, domain_ids: [1]} =
               dataset

      assert headers == ["CODE", "DESC_ES", "DESC_EN"]

      assert rows == [
               ["DE", "Alemania", "Germany"],
               ["ES", "España", "Spain"],
               ["FR", "Francia", "France"],
               ["NL", "Holanda", "Netherlands"],
               ["UK", "Reino Unido", "United Kingdom"]
             ]
    end
  end

  describe "ReferenceData.update/1" do
    test "updates a dataset with valid data" do
      %{name: name} = dataset = insert(:reference_dataset)

      assert {:ok, dataset} =
               ReferenceData.update(dataset, %{
                 name: name,
                 path: "test/fixtures/reference_data/dataset1.csv",
                 domain_ids: [1]
               })

      assert %{name: ^name, headers: headers, rows: rows, row_count: 5, domain_ids: [1]} = dataset
      assert headers == ["CODE", "DESC_ES", "DESC_EN"]

      assert rows == [
               ["DE", "Alemania", "Germany"],
               ["ES", "España", "Spain"],
               ["FR", "Francia", "France"],
               ["NL", "Holanda", "Netherlands"],
               ["UK", "Reino Unido", "United Kingdom"]
             ]
    end
  end

  describe "ReferenceData.to_csv/1" do
    test "encodes a dataset as CSV" do
      dataset = insert(:reference_dataset)

      assert ReferenceData.to_csv(dataset) ==
               "FOO;BAR;BAZ\r\nfoo1;bar1;baz1\r\nfoo2;bar2;baz2\r\n"
    end
  end
end

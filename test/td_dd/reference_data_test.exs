defmodule TdDd.ReferenceDataTest do
  use TdDd.DataCase

  alias TdDd.ReferenceData

  describe "ReferenceData.create/1" do
    test "creates a dataset with valid data" do
      assert {:ok, dataset} =
               ReferenceData.create("Countries", "test/fixtures/reference_data/dataset1.csv")

      assert %{name: "Countries", headers: headers, rows: rows} = dataset
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
               ReferenceData.update(dataset, "test/fixtures/reference_data/dataset1.csv")

      assert %{name: ^name, headers: headers, rows: rows} = dataset
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
end

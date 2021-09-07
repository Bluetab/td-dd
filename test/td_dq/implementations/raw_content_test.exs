defmodule TdDq.Implementations.RawContentTest do
  use ExUnit.Case

  alias TdDq.Implementations.RawContent

  describe "changeset/2" do
    test "base64 decodes dataset, population and validations" do
      params = %{
        "dataset" => Base.encode64("dataset"),
        "population" => Base.encode64("population"),
        "validations" => Base.encode64("validations")
      }

      assert %{changes: changes} = RawContent.changeset(%RawContent{}, params)

      assert %{
               dataset: "dataset",
               population: "population",
               validations: "validations"
             } = changes
    end
  end

  test "preserves dataset, population and validations if not base64 encoded" do
    params = %{
      "dataset" => "dataset",
      "population" => "population",
      "validations" => "validations"
    }

    assert %{changes: changes} = RawContent.changeset(%RawContent{}, params)

    assert %{
             dataset: "dataset",
             population: "population",
             validations: "validations"
           } = changes
  end
end

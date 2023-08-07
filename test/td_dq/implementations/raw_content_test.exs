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

  test "valid changeset" do
    params = %{
      "source_id" => 1,
      "dataset" => Base.encode64("TPERSONS p"),
      "population" => Base.encode64("p.hobby = '漫画'"),
      # validation just checks for certain keywords/characters. Middle
      # semicolon is invalid SQL but it is still accepted.
      "validations" => Base.encode64("p.age IS NOT ; NULL; # some comment")
    }

    assert %{changes: changes, valid?: true} = RawContent.changeset(%RawContent{}, params)

    assert %{
             dataset: "TPERSONS p",
             population: "p.hobby = '漫画'",
             validations: "p.age IS NOT ; NULL; # some comment",
           } = changes
  end

  test "invalid changeset" do
    params = %{
      "source_id" => 1,
      "dataset" => Base.encode64("TPERSONS p"),
      "population" => Base.encode64("p.hobby = '漫画'"),
      "validations" => Base.encode64("p.age IS NOT NULL; DROP TABLE TPERSONS;")
    }

    assert %{
      changes: _changes,
      valid?: false,
      errors: [validations: {"invalid.validations", [validation: :invalid_content]}],
    } = RawContent.changeset(%RawContent{}, params)
  end

end

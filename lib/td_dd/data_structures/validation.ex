defmodule TdDd.DataStructures.Validation do
  @moduledoc """
  Provides functions for merging and validating data structure dynamic content.
  """
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDfLib.Templates
  alias TdDfLib.Validation

  @doc """
  Returns a validator function that can be used by
  `Ecto.Changeset.validate_change/3`
  """
  def validator(%DataStructure{} = structure) do
    case DataStructures.template_name(structure) do
      nil ->
        empty_content_validator()

      template ->
        Validation.validator(template)
    end
  end

  def validator(%DataStructure{} = structure, df_content, fields) do
    structure
    |> DataStructures.template_name()
    |> Templates.content_schema()
    |> case do
      {:error, error} -> {:error, error}
      schema -> validate(schema, df_content, fields)
    end
  end

  defp empty_content_validator do
    fn
      _, nil -> []
      _, value when value == %{} -> []
      field, _ -> [{field, :missing_type}]
    end
  end

  defp validate(schema, df_content, fields) do
    Validation.build_changeset(
      df_content,
      Enum.filter(schema, fn %{"name" => name} -> name in fields end)
    )
  end
end

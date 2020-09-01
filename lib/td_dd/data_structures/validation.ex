defmodule TdDd.DataStructures.Validation do
  @moduledoc """
  Provides functions for merging and validating data structure dynamic content.
  """
  alias TdCache.StructureTypeCache
  alias TdCache.TemplateCache
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDfLib.Templates
  alias TdDfLib.Validation

  @doc """
  Returns a validator function that can be used by
  `Ecto.Changeset.validate_change/3`
  """
  def validator(%DataStructure{} = structure) do
    case template_name(structure) do
      nil ->
        empty_content_validator()

      template ->
        Validation.validator(template)
    end
  end

  def validator(%DataStructure{} = structure, df_content, fields) do
    structure
    |> template_name()
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

  defp template_name(%DataStructure{} = data_structure) do
    data_structure
    |> DataStructures.get_latest_version()
    |> template_name()
  end

  defp template_name(%DataStructureVersion{type: type}) do
    with {:ok, %{template_id: template_id}} <- StructureTypeCache.get_by_type(type),
         {:ok, %{name: name}} <- TemplateCache.get(template_id) do
      name
    else
      _ -> ""
    end
  end

  defp template_name(_), do: nil

  defp validate(schema, df_content, fields) do
    Validation.build_changeset(
      df_content,
      Enum.filter(schema, fn %{"name" => name} -> name in fields end)
    )
  end
end

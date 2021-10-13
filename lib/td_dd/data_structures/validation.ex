defmodule TdDd.DataStructures.Validation do
  @moduledoc """
  Provides functions for merging and validating data structure dynamic content.
  """
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.StructureNote
  alias TdDfLib.Templates
  alias TdDfLib.Validation

  @doc """
  Returns a validator function that can be used by
  `Ecto.Changeset.validate_change/3`
  """
  def validator(%DataStructure{domain_id: domain_id} = structure) do
    case DataStructures.template_name(structure) do
      nil ->
        empty_content_validator()

      template ->
        Validation.validator(template, domain_id: domain_id)
    end
  end

  def validator(%StructureNote{data_structure: structure} = note) do
    case DataStructures.template_name(note) do
      nil ->
        empty_content_validator()

      template ->
        domain_id = Map.get(structure, :domain_id)
        Validation.validator(template, domain_id: domain_id)
    end
  end

  def validator(%DataStructure{domain_id: domain_id} = data_structure, df_content, fields) do
    data_structure
    |> DataStructures.template_name()
    |> Templates.content_schema()
    |> case do
      {:error, error} -> {:error, error}
      schema -> validate(schema, df_content, fields, domain_id)
    end
  end

  def validator(%StructureNote{data_structure: structure} = note, df_content, fields) do
    note
    |> DataStructures.template_name()
    |> Templates.content_schema()
    |> case do
      {:error, error} ->
        {:error, error}

      schema ->
        domain_id = Map.get(structure, :domain_id)
        validate(schema, df_content, fields, domain_id)
    end
  end

  defp empty_content_validator do
    fn
      _, nil -> []
      _, value when value == %{} -> []
      field, _ -> [{field, :missing_type}]
    end
  end

  defp validate(schema, df_content, fields, domain_id) do
    Validation.build_changeset(
      df_content,
      Enum.filter(schema, fn %{"name" => name} -> name in fields end),
      domain_id: domain_id
    )
  end
end

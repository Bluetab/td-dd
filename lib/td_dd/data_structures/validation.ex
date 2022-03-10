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
  def validator(%DataStructure{domain_ids: domain_ids} = structure) do
    case DataStructures.template_name(structure) do
      nil ->
        empty_content_validator()

      template ->
        # FIXME: TD-4500 TdDfLib.Validation.validator with domain_ids
        Validation.validator(template, domain_ids: domain_ids)
    end
  end

  def validator(%StructureNote{data_structure: structure}) do
    validator(structure)
  end

  @spec validator(
          %{
            :__struct__ => TdDd.DataStructures.DataStructure | TdDd.DataStructures.StructureNote,
            optional(any) => any
          },
          any,
          any
        ) :: {:error, :template_not_found} | Ecto.Changeset.t()
  def validator(%DataStructure{domain_ids: domain_ids} = data_structure, df_content, fields) do
    data_structure
    |> DataStructures.template_name()
    |> Templates.content_schema()
    |> case do
      {:error, error} -> {:error, error}
      schema -> validate(schema, df_content, fields, domain_ids)
    end
  end

  def validator(%StructureNote{data_structure: structure}, df_content, fields) do
    validator(structure, df_content, fields)
  end

  def shallow_validator(%{} = structure) do
    case DataStructures.template_name(structure) do
      "" -> empty_content_validator()
      nil -> empty_content_validator()
      _ -> fn _, _ -> [] end
    end
  end

  defp empty_content_validator do
    fn
      _, nil -> []
      _, value when value == %{} -> []
      field, _ -> [{field, "missing_type"}]
    end
  end

  defp validate(schema, df_content, fields, domain_ids) do
    # FIXME: TD-4500 TdDfLib.Validation.build_changeset with domain_ids
    Validation.build_changeset(
      df_content,
      Enum.filter(schema, fn %{"name" => name} -> name in fields end),
      domain_ids: domain_ids
    )
  end
end

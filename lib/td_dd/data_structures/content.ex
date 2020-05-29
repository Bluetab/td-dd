defmodule TdDd.DataStructures.Content do
  @moduledoc """
  Provides functions for merging and validating data structure dynamic content.
  """

  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDfLib.Validation

  def merge(content, current_content)

  def merge(nil = _content, _current_content), do: nil

  def merge(content, nil = _current_content), do: content

  def merge(%{} = content, %{} = current_content) do
    Map.merge(content, current_content, fn _field, new_val, _current_val -> new_val end)
  end

  @doc """
  Returns a validator function that can be used by
  `Ecto.Changeset.validate_change/3`
  """
  def validator(%DataStructure{} = structure) do
    case template_name(structure) do
      nil -> empty_content_validator()
      template -> Validation.validator(template)
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

  defp template_name(%DataStructureVersion{type: type}), do: type

  defp template_name(_), do: nil
end

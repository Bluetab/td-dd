defmodule Templates do
  @moduledoc """
  Template support for Business Glossary tests
  """

  alias TdCache.TemplateCache

  def create_template(type, content) do
    attrs = %{
      id: 0,
      label: type,
      name: type,
      scope: "cx",
      content: content
    }

    put_template(attrs)
  end

  def create_template(attrs) do
    put_template(attrs)
  end

  def create_template do
    attrs = %{
      id: 0,
      label: "some type",
      name: "some_type",
      scope: "cx",
      content: []
    }

    put_template(attrs)
  end

  def delete(%{id: id}) do
    TemplateCache.delete(id)
  end

  defp put_template(%{updated_at: _updated_at} = attrs) do
    TemplateCache.put(attrs)
    Map.delete(attrs, :updated_at)
  end

  defp put_template(%{} = attrs) do
    attrs
    |> Map.put(:updated_at, DateTime.utc_now())
    |> put_template()
  end
end

defmodule TdDdWeb.Resolvers.Templates do
  @moduledoc """
  Absinthe resolvers for templates
  """

  alias TdCache.TemplateCache
  alias TdCache.Templates.Preprocessor

  def templates(_parent, args, resolution) do
    args
    |> get_templates()
    |> maybe_preprocess(args, resolution)
  end

  defp get_templates(%{scope: scope}) when is_binary(scope),
    do: TemplateCache.list_by_scope(scope)

  defp get_templates(_), do: TemplateCache.list()

  defp maybe_preprocess({:ok, templates}, %{domain_ids: [_ | _] = domain_ids}, %{context: %{claims: claims}}) do
    domain_ids = domain_ids
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&String.to_integer/1)

    templates = Enum.map(
      templates,
      &Preprocessor.preprocess_template(&1, %{domain_ids: domain_ids, claims: claims})
    )
    {:ok, templates}
  end

  defp maybe_preprocess(templates, _, _), do: templates

  def updated_at(%{updated_at: value}, _args, _resolution) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _} -> {:ok, datetime}
      {:error, error} -> {:error, error}
    end
  end
end

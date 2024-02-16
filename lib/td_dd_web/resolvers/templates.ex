defmodule TdDdWeb.Resolvers.Templates do
  @moduledoc """
  Absinthe resolvers for templates
  """

  alias TdCache.TemplateCache
  alias TdCache.Templates.Preprocessor

  def template(_parent, args, resolution) do
    args
    |> get_template_by_name()
    |> maybe_preprocess_template(args, resolution)
  end

  def templates(_parent, args, resolution) do
    args
    |> get_templates()
    |> maybe_preprocess_list(args, resolution)
  end

  defp get_templates(%{scope: scope}) when is_binary(scope),
    do: TemplateCache.list_by_scope(scope)

  defp get_templates(_), do: TemplateCache.list()

  defp get_template_by_name(%{name: name}) do
    TemplateCache.get_by_name(name)
  end

  defp maybe_preprocess_template({:ok, template}, %{domain_ids: [_ | _] = domain_ids}, %{
         context: %{claims: claims}
       }) do
    domain_ids =
      domain_ids
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&String.to_integer/1)

    template =
      Preprocessor.preprocess_template(template, %{domain_ids: domain_ids, claims: claims})

    {:ok, template}
  end

  defp maybe_preprocess_template(template, _, _), do: template

  defp maybe_preprocess_list({:ok, templates}, %{domain_ids: [_ | _] = domain_ids}, %{
         context: %{claims: claims}
       }) do
    domain_ids =
      domain_ids
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&String.to_integer/1)

    templates =
      Enum.map(
        templates,
        &Preprocessor.preprocess_template(&1, %{domain_ids: domain_ids, claims: claims})
      )

    {:ok, templates}
  end

  defp maybe_preprocess_list(templates, _, _), do: templates

  def updated_at(%{updated_at: value}, _args, _resolution) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _} -> {:ok, datetime}
      {:error, error} -> {:error, error}
    end
  end
end

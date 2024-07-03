defmodule TdCxWeb.ConfigurationView do
  use TdCxWeb, :view
  alias TdCx.Format
  alias TdCxWeb.ConfigurationView
  alias TdDfLib.Content

  def render("index.json", %{configurations: configurations}) do
    %{data: render_many(configurations, ConfigurationView, "configuration.json")}
  end

  def render("show.json", %{configuration: configuration}) do
    %{data: render_one(configuration, ConfigurationView, "configuration.json")}
  end

  def render("configuration.json", %{configuration: configuration}) do
    %{
      id: configuration.id,
      content: configuration.content,
      external_id: configuration.external_id,
      secrets_key: configuration.secrets_key,
      type: configuration.type
    }
    |> add_cached_content()
    |> Content.legacy_content_support(:content)
  end

  defp add_cached_content(configuration) do
    type = Map.get(configuration, :type)

    content =
      configuration
      |> Map.get(:content)
      |> Format.get_cached_content(type)

    Map.put(configuration, :content, content)
  end
end

defmodule TdCxWeb.ConfigurationView do
  use TdCxWeb, :view
  alias TdCxWeb.ConfigurationView

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
  end
end

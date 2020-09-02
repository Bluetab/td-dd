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
    %{id: configuration.id,
      config: configuration.config,
      external_id: configuration.external_id,
      secrets_key: configuration.secrets_key,
      type: configuration.type,
      deleted_at: configuration.deleted_at}
  end
end

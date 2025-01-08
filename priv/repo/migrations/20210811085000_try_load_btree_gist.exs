defmodule TdDd.Repo.Migrations.TryLoadBtreeGist do
  use Ecto.Migration
  @disable_ddl_transaction true

  import Ecto.Query

  require Logger

  @extension "btree_gist"

  def up do
    unless extension_exists?(@extension) do
      case repo().query("CREATE EXTENSION IF NOT EXISTS #{@extension}") do
        {:ok, _} ->
          :ok

        {:error, %{postgres: %{message: message}}} ->
          Logger.warning(message)
          Logger.warning("Superuser must execute 'CREATE EXTENSION IF NOT EXISTS #{@extension}'")

        _ ->
          Logger.warning("Superuser must execute 'CREATE EXTENSION IF NOT EXISTS #{@extension}'")
      end
    end
  end

  def down, do: :ok

  defp extension_exists?(name) do
    "pg_extension"
    |> where(extname: ^name)
    |> repo().exists?()
  rescue
    _ -> false
  end
end

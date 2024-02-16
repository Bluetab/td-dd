defmodule TdDdWeb.DataStructureLinkView do
  use TdDdWeb, :view

  alias TdDd.DataStructures.DataStructure

  def render(
        "bulk_create.json",
        %{
          result: %{
            inserted: inserted,
            not_inserted: %{
              changeset_invalid_links: changest_invalid_links,
              inexistent_structure: inexistent_structure
            }
          }
        }
      ) do
    data = %{
      inserted: render_many(inserted, __MODULE__, "data_structure_link.json"),
      not_inserted: %{
        changeset_invalid_links: changest_invalid_links,
        inexistent_structure:
          render_many(inexistent_structure, __MODULE__, "data_structure_link.json")
      }
    }

    %{data: data}
  end

  def render("index.json", %{data_structure_links: links}) do
    %{data: render_many(links, __MODULE__, "data_structure_link.json")}
  end

  def render("show.json", %{data_structure_link: link}) do
    %{data: render_one(link, __MODULE__, "data_structure_link.json")}
  end

  def render("data_structure_link.json", %{
        data_structure_link:
          %{
            source: %DataStructure{} = source,
            target: %DataStructure{} = target,
            labels: labels
          } = link
      }) do
    Map.take(link, [:source_external_id, :target_external_id, :inserted_at])
    |> Map.put(
      :source,
      render_one(source, TdDdWeb.DataStructureView, "with_current_version.json")
    )
    |> Map.put(
      :target,
      render_one(target, TdDdWeb.DataStructureView, "with_current_version.json")
    )
    |> Map.put(:labels, Enum.map(labels, &Map.get(&1, :name)))
  end

  def render(
        "data_structure_link.json",
        %{
          data_structure_link:
            %{
              source_external_id: source_external_id,
              target_external_id: target_external_id
            } = link
        }
      )
      when is_binary(source_external_id) and is_binary(target_external_id) do
    Map.take(link, [:source_external_id, :target_external_id, :inserted_at])
  end

  def render(
        "data_structure_link.json",
        %{data_structure_link: link}
      ) do
    Map.take(link, [:source_id, :target_id, :inserted_at])
  end
end

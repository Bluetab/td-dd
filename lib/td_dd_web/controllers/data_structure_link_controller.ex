defmodule TdDdWeb.DataStructureLinkController do
  use TdDdWeb, :controller

  action_fallback(TdDdWeb.FallbackController)

  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructureLink
  alias TdDd.DataStructures.DataStructureLinks

  alias Truedat.Auth.Claims

  def index(conn, %{"data_structure_id" => data_structure_id} = _params) do
    claims = conn.assigns[:current_resource]

    with links <- DataStructureLinks.all_by_id(data_structure_id),
         :ok <- Bodyguard.permit(DataStructureLinks, :view, claims, links) do
      render(conn, "index.json", data_structure_links: links)
    end
  end

  def index_by_external_id(conn, %{"external_id" => external_id}) do
    claims = conn.assigns[:current_resource]

    with links <- DataStructureLinks.all_by_external_id(external_id),
         :ok <- Bodyguard.permit(DataStructureLinks, :view, claims, links) do
      render(conn, "index.json", data_structure_links: links)
    end
  end

  def show(conn, %{"source_id" => _source_id, "target_id" => _target_id} = params) do
    claims = conn.assigns[:current_resource]

    with %DataStructureLink{} = link <- DataStructureLinks.get_by(params),
         :ok <- Bodyguard.permit(DataStructureLinks, :view, claims, link) do
      render(conn, "show.json", data_structure_link: link)
    end
  end

  def show_by_external_ids(
        conn,
        %{
          "source_external_id" => _source_external_id,
          "target_external_id" => _target_external_id
        } = params
      ) do
    claims = conn.assigns[:current_resource]

    with %DataStructureLink{} = link <- DataStructureLinks.get_by(params),
         :ok <- Bodyguard.permit(DataStructureLinks, :view, claims, link) do
      render(conn, "show.json", data_structure_link: link)
    end
  end

  def search(conn, params) do
    claims = conn.assigns[:current_resource]

    with {:ok, %{data_structure_links: links} = result} <- DataStructureLinks.search(params),
         :ok <- Bodyguard.permit(DataStructureLinks, :view, claims, links) do
      render(conn, "search.json", result: result)
    end
  end

  def delete(
        conn,
        %{
          "source_id" => _non_validated_source_id,
          "target_id" => _non_validated_target_id
        } = params
      ) do
    %{user_id: user_id} = claims = conn.assigns[:current_resource]

    with {:ok, %Ecto.Changeset{changes: %{source_id: source_id, target_id: target_id}}} <-
           DataStructureLinks.validate_params(params),
         %DataStructureLink{} = link <-
           DataStructureLinks.get_by(%{source_id: source_id, target_id: target_id}),
         :ok <- Bodyguard.permit(DataStructureLinks, :delete, claims, link),
         {:ok, _} <- DataStructureLinks.delete_and_audit(link, user_id) do
      send_resp(conn, :no_content, "")
    end
  end

  def delete_by_external_ids(
        conn,
        %{
          "source_external_id" => _source_external_id,
          "target_external_id" => _target_external_id
        } = params
      ) do
    claims = conn.assigns[:current_resource]

    with %DataStructureLink{} = link <- DataStructureLinks.get_by(params),
         :ok <- Bodyguard.permit(DataStructureLinks, :delete, claims, link),
         {:ok, %DataStructureLink{}} <- DataStructureLinks.delete(link) do
      send_resp(conn, :no_content, "")
    end
  end

  def create(conn, %{"data_structure_link" => link}) do
    %Claims{user_id: user_id} = claims = conn.assigns[:current_resource]

    with {:ok,
          %Ecto.Changeset{changes: %{source_id: source_id, target_id: target_id}} = changeset} <-
           DataStructureLinks.validate_params(link),
         [source_structure, target_structure] <-
           DataStructures.get_data_structures([source_id, target_id]),
         :ok <-
           Bodyguard.permit(
             DataStructureLinks,
             :create,
             claims,
             {source_structure, target_structure}
           ),
         {:ok, %{data_structure_link: data_structure_link}} <-
           DataStructureLinks.create_and_audit(changeset, user_id) do
      conn
      |> put_status(:created)
      |> render("show.json", %{data_structure_link: data_structure_link})
    end
  end

  def create(conn, %{"data_structure_links" => links}) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(DataStructureLinks, :link_structure_to_structure, claims),
         {:ok, result} <-
           DataStructureLinks.bulk_load(links) do
      conn
      |> put_status(:created)
      |> render("bulk_create.json", result: result)
    end
  end
end

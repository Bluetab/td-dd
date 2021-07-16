defmodule TdDdWeb.GrantController do
  use TdDdWeb, :controller
  import Canada, only: [can?: 2]

  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure

  alias TdDd.Grants
  alias TdDd.Grants.Grant

  action_fallback TdDdWeb.FallbackController

  def create(conn, %{"grant" => grant_params, "data_structure_id" => data_structure_external_id}) do
    with claims <- conn.assigns[:current_resource],
         %DataStructure{} = data_structure <-
           DataStructures.get_data_structure_by_external_id(data_structure_external_id),
         {:can, true} <- {:can, can?(claims, create_grant(data_structure))},
         {:ok, %Grant{} = grant} <- Grants.create_grant(grant_params, data_structure) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.grant_path(conn, :show, grant))
      |> render("show.json", grant: grant)
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  def show(conn, %{"id" => id}) do
    grant = Grants.get_grant!(id)
    render(conn, "show.json", grant: grant)
  end

  def update(conn, %{"id" => id, "grant" => grant_params}) do
    grant = Grants.get_grant!(id)

    with {:ok, %Grant{} = grant} <- Grants.update_grant(grant, grant_params) do
      render(conn, "show.json", grant: grant)
    end
  end

  def delete(conn, %{"id" => id}) do
    grant = Grants.get_grant!(id)

    with {:ok, %Grant{}} <- Grants.delete_grant(grant) do
      send_resp(conn, :no_content, "")
    end
  end
end

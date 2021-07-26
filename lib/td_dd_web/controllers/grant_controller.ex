defmodule TdDdWeb.GrantController do
  use TdDdWeb, :controller
  use PhoenixSwagger
  import Canada, only: [can?: 2]

  alias TdCache.UserCache
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure

  alias TdDd.Grants
  alias TdDd.Grants.Grant
  alias TdDdWeb.SwaggerDefinitions

  action_fallback(TdDdWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.grant_swagger_definitions()
  end

  swagger_path :create do
    description("Creates a Grant")
    produces("application/json")

    parameters do
      data_structure_external_id(:path, :string, "Data Structure External Id", required: true)

      grant(
        :body,
        Schema.ref(:GrantCreate),
        "Grant create attrs"
      )
    end

    response(201, "OK", Schema.ref(:GrantResponse))
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  def create(conn, %{"grant" => grant_params, "data_structure_id" => data_structure_external_id}) do
    with claims <- conn.assigns[:current_resource],
         {:data_structure, %DataStructure{} = data_structure} <-
           {:data_structure,
            DataStructures.get_data_structure_by_external_id(data_structure_external_id)},
         {:can, true} <- {:can, can?(claims, create_grant(data_structure))},
         {:ok, grant_params} <- with_user_id(grant_params),
         {:ok, %{grant: %Grant{} = grant}} <-
           Grants.create_grant(grant_params, data_structure, claims) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.grant_path(conn, :show, grant))
      |> render("show.json", grant: grant)
    else
      {:data_structure, nil} -> {:error, :not_found, "DataStructure"}
      error -> error
    end
  end

  defp with_user_id(%{"user_id" => user_id} = grant_params) do
    case UserCache.get(user_id) do
      {:ok, nil} ->
        {:error, :not_found, "User"}

      {:ok, user} ->
        {:ok, Map.put(grant_params, "user_id", user.id)}
    end
  end

  defp with_user_id(%{"user_name" => user_name} = grant_params) do
    case UserCache.get_by_user_name(user_name) do
      {:ok, nil} ->
        {:error, :not_found, "User"}

      {:ok, user} ->
        {:ok, Map.put(grant_params, "user_id", user.id)}
    end
  end

  defp with_user_id(params), do: {:ok, params}

  swagger_path :show do
    description("Shows Grant")
    produces("application/json")

    parameters do
      id(:path, :string, "Grant Id", required: true)
    end

    response(200, "OK", Schema.ref(:GrantResponse))
    response(403, "Forbidden")
    response(404, "Not Found")
  end

  def show(conn, %{"id" => id}) do
    with claims <- conn.assigns[:current_resource],
         %Grant{} = grant <- Grants.get_grant!(id, preload: [data_structure: :versions]),
         {:can, true} <- {:can, can?(claims, show(grant))} do
      render(conn, "show.json", grant: grant)
    end
  end

  swagger_path :update do
    description("Updates Grant")
    produces("application/json")

    parameters do
      id(:path, :string, "Grant Id", required: true)

      grant(
        :body,
        Schema.ref(:GrantUpdate),
        "Grant update attrs"
      )
    end

    response(201, "OK", Schema.ref(:GrantResponse))
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  def update(conn, %{"id" => id, "grant" => grant_params}) do
    with claims <- conn.assigns[:current_resource],
         %Grant{} = grant <- Grants.get_grant!(id, preload: [:data_structure]),
         {:can, true} <- {:can, can?(claims, update(grant))},
         {:ok, %{grant: %Grant{} = grant}} <- Grants.update_grant(grant, grant_params, claims) do
      render(conn, "show.json", grant: grant)
    end
  end

  swagger_path :delete do
    description("Deletes a Grant")
    produces("application/json")

    parameters do
      id(:path, :integer, "Grant ID", required: true)
    end

    response(202, "Accepted")
    response(403, "Forbidden")
    response(422, "Unprocessable Entity")
  end

  def delete(conn, %{"id" => id}) do
    with claims <- conn.assigns[:current_resource],
         %Grant{} = grant <- Grants.get_grant!(id, preload: [:data_structure]),
         {:can, true} <- {:can, can?(claims, delete(grant))},
         {:ok, %{grant: %Grant{}}} <- Grants.delete_grant(grant, claims) do
      send_resp(conn, :no_content, "")
    end
  end
end

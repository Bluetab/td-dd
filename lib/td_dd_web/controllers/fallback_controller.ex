defmodule TdDdWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use TdDdWeb, :controller

  require Logger

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(TdDdWeb.ChangesetView)
    |> render("error.json", changeset: changeset)
  end

  def call(conn, {:error, _field, %Ecto.Changeset{} = changeset, _changes_so_far}) do
    call(conn, {:error, changeset})
  end

  def call(conn, {:error, :unprocessable_entity, message}) do
    conn
    |> put_resp_content_type("application/json", "utf-8")
    |> send_resp(:unprocessable_entity, Jason.encode!(%{message: message}))
  end

  def call(conn, {:error, :not_found, message}) do
    conn
    |> put_resp_content_type("application/json", "utf-8")
    |> send_resp(:not_found, Jason.encode!(%{message: message}))
  end

  def call(conn, nil) do
    render_error(conn, :not_found)
  end

  def call(conn, {:error, :not_found}) do
    render_error(conn, :not_found)
  end

  def call(conn, {:error, :conflict}) do
    render_error(conn, :conflict)
  end

  def call(conn, {:error, :forbidden}) do
    render_error(conn, :forbidden)
  end

  def call(conn, {:error, error}) do
    conn
    |> put_resp_content_type("application/json", "utf-8")
    |> send_resp(:unprocessable_entity, Jason.encode!(%{error: error}))
  end

  def call(conn, {:can, false}) do
    render_error(conn, :forbidden)
  end

  def call(conn, {:cp, {:error, error}}) do
    Logger.warning("File copy operation failed with error #{inspect(error)}")
    render_error(conn, :insufficient_storage)
  end

  def call(conn, {:error, :update_notes, {%Ecto.Changeset{errors: errors}, %{row: row}}, _}) do
    {field, error_message} =
      errors
      |> Enum.map(fn {k, v} ->
        case v do
          {_error, [{field, {_, [{_, e} | _]}} | _]} -> {field, "#{k}.#{e}"}
          _ -> {nil, "#{k}.default"}
        end
      end)
      |> Enum.at(0, {nil, "default"})

    error = %{
      errors: %{
        row: row,
        field: field,
        note: [error_message]
      }
    }

    conn
    |> put_resp_content_type("application/json", "utf-8")
    |> send_resp(:unprocessable_entity, Jason.encode!(error))
  end

  def call(conn, {:error, :update_notes, {action, data_structure}, _struct}) do
    error = %{
      errors: %{
        row: data_structure.row,
        note: [action]
      }
    }

    conn
    |> put_resp_content_type("application/json", "utf-8")
    |> send_resp(:unprocessable_entity, Jason.encode!(error))
  end

  def call(conn, {:forbidden, [{_, %{row_meta: %{index: index}}} | _]}) do
    error = %{
      errors: %{
        row: index,
        note: [:insufficient_permissions]
      }
    }

    conn
    |> put_resp_content_type("application/json", "utf-8")
    |> send_resp(:forbidden, Jason.encode!(error))
  end
end

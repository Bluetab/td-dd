defmodule TdDdWeb.GrantRequestApprovalView do
  use TdDdWeb, :view

  alias TdDdWeb.UserView

  def render("show.json", %{grant_request_approval: approval}) do
    %{data: render_one(approval, __MODULE__, "grant_request_approval.json")}
  end

  def render("grant_request_approval.json", %{grant_request_approval: approval}) do
    approval
    |> Map.take([:id, :role, :is_rejection, :comment, :inserted_at])
    |> put_embeddings(approval)
  end

  defp put_embeddings(%{} = resp, approval) do
    case embeddings(approval) do
      map when map == %{} -> resp
      embeddings -> Map.put(resp, :_embedded, embeddings)
    end
  end

  defp embeddings(%{} = approval) do
    approval
    |> Map.take([:user])
    |> Enum.reduce(%{}, fn
      {:user, %{} = user}, acc ->
        Map.put(acc, :user, render_one(user, UserView, "embedded.json"))

      _, acc ->
        acc
    end)
  end
end

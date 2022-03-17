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
      :none -> resp
      %{} = embeddings -> Map.put(resp, :_embedded, embeddings)
    end
  end

  defp embeddings(%{user: user} = _approval) do
    %{user: render_one(user, UserView, "embedded.json")}
  end

  defp embeddings(_approval), do: :none
end

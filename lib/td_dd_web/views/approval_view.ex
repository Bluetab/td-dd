defmodule TdDdWeb.ApprovalView do
  use TdDdWeb, :view

  alias TdDdWeb.DomainView
  alias TdDdWeb.UserView

  def render("show.json", %{approval: approval}) do
    %{data: render_one(approval, __MODULE__, "approval.json")}
  end

  def render("approval.json", %{approval: approval}) do
    approval
    |> Map.take([:id, :role, :is_rejection, :comment])
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
    |> Map.take([:user, :domain])
    |> Enum.reduce(%{}, fn
      {:user, %{} = user}, acc ->
        Map.put(acc, :user, render_one(user, UserView, "embedded.json"))

      {:domain, %{} = domain}, acc ->
        Map.put(acc, :domain, render_one(domain, DomainView, "embedded.json"))

      _, acc ->
        acc
    end)
  end
end

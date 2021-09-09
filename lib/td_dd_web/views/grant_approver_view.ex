defmodule TdDdWeb.GrantApproverView do
  use TdDdWeb, :view

  def render("index.json", %{grant_approvers: grant_approvers}) do
    %{data: render_many(grant_approvers, __MODULE__, "grant_approver.json")}
  end

  def render("show.json", %{grant_approver: grant_approver}) do
    %{data: render_one(grant_approver, __MODULE__, "grant_approver.json")}
  end

  def render("grant_approver.json", %{grant_approver: grant_approver}) do
    %{
      id: grant_approver.id,
      name: grant_approver.name
    }
  end
end

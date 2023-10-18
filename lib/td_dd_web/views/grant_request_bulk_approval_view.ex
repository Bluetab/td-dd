defmodule TdDdWeb.GrantRequestBulkApprovalView do
  use TdDdWeb, :view

  def render("show.json", %{grant_request_bulk_approval: approvals}) do
    %{data: render_many(approvals, __MODULE__, "grant_request_approval.json")}
  end

  def render("grant_request_approval.json", %{grant_request_bulk_approval: approval}) do
    Map.take(approval, [:id, :role, :is_rejection, :comment, :inserted_at])
  end
end

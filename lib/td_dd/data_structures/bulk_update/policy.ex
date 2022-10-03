defmodule TdDd.DataStructures.BulkUpdate.Policy do
  @moduledoc "Authorization rules for TdDd.DataStructures.BulkUpdate"

  alias TdDd.Permissions

  @behaviour Bodyguard.Policy

  # Admin accounts can do anything with data structures
  def authorize(_action, %{role: "admin"}, _params), do: true

  def authorize(:auto_publish, %{role: "user"} = claims, _params) do
    Permissions.authorized?(claims, :publish_structure_note_from_draft)
  end

  def authorize(:bulk_upload, %{role: "user"} = claims, _params) do
    Permissions.authorized?(claims, [:create_structure_note, :edit_structure_note])
  end

  def authorize(:bulk_upload_domains, %{role: "user"} = claims, _params) do
    Permissions.authorized?(claims, :manage_structures_domain)
  end

  # bulk_update is admin only
  def authorize(:bulk_update, _claims, _params), do: false

  def authorize(_action, _claims, _params), do: false
end

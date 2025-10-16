defmodule TdDq.Implementations.Actions do
  @moduledoc """
  The Implementations Actions context.
  """

  use TdDqWeb, :controller

  alias TdDq.Implementations.Implementation
  alias TdDq.Rules.Rule

  defdelegate authorize(action, user, params), to: TdDq.Implementations.Policy

  @publish_actions [
    :auto_publish,
    "download",
    "execute",
    "create",
    "createBasic",
    "createBasicRuleLess",
    "createRaw",
    "createRawRuleLess",
    "createRuleLess",
    "uploadResults"
  ]

  defp get_available_actions(_params, %Implementation{}) do
    [
      :auto_publish,
      :clone,
      :delete,
      :edit,
      :execute,
      :link_concept,
      :view_published_concept,
      :view_draft_concept,
      :view_approval_pending_concept,
      :link_structure,
      :manage_segments,
      :move,
      :publish,
      :restore,
      :reject,
      :submit,
      :convert_raw,
      :convert_default
    ]
  end

  defp get_available_actions(%{"filters" => %{"status" => ["published"]}}, Implementation) do
    @publish_actions
  end

  defp get_available_actions(%{"must" => %{"status" => ["published"]}}, Implementation) do
    @publish_actions
  end

  defp get_available_actions(_params, Implementation) do
    [
      :auto_publish,
      "create",
      "createBasic",
      "createBasicRuleLess",
      "createRaw",
      "createRawRuleLess",
      "createRuleLess",
      "download",
      "load"
    ]
  end

  def put_actions(conn, claims), do: put_actions(conn, claims, %{}, Implementation)

  def put_actions(conn, claims, %Implementation{} = implementation),
    do: put_actions(conn, claims, %{}, implementation)

  def put_actions(conn, claims, %Rule{} = rule) do
    [
      :auto_publish,
      "create",
      "createBasic",
      "createRaw"
    ]
    |> Enum.filter(&Bodyguard.permit?(TdDq.Rules, &1, claims, rule))
    |> Map.new(fn
      :auto_publish ->
        {"autoPublish",
         %{
           href: Routes.implementation_upload_path(conn, :create),
           method: "POST"
         }}

      action ->
        {action, %{method: "POST"}}
    end)
    |> then(&assign(conn, :actions, &1))
  end

  def put_actions(conn, claims, params), do: put_actions(conn, claims, params, Implementation)

  def put_actions(conn, claims, params, implementation) do
    params
    |> get_available_actions(implementation)
    |> Enum.filter(&Bodyguard.permit?(TdDq.Implementations, &1, claims, implementation))
    |> Map.new(fn
      :auto_publish ->
        {"autoPublish",
         %{
           href: Routes.implementation_upload_path(conn, :create),
           method: "POST"
         }}

      action ->
        {action, %{method: "POST"}}
    end)
    |> then(&assign(conn, :actions, &1))
  end
end

defmodule TdDq.Implementations.Actions do

  use TdDqWeb, :controller

  alias TdDq.Implementations.Implementation

  defdelegate authorize(action, user, params), to: TdDq.Implementations.Policy

  defp get_available_actions(_params, %Implementation{}) do
    [
      :auto_publish,
      :clone,
      :delete,
      :edit,
      :execute,
      :link_concept,
      :link_structure,
      :manage_segments,
      :move,
      :publish,
      :restore,
      :reject,
      :submit
    ]
  end

  defp get_available_actions(%{"filters" => %{"status" => ["published"]}}, Implementation) do
    [
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

  def put_actions(conn, claims, params), do: put_actions(conn, claims, params, Implementation)

  def put_actions(conn, claims, params, implementation) do
    params
    |> get_available_actions(implementation)
    |> Enum.filter(&Bodyguard.permit?(TdDq.Implementations, &1, claims, implementation))
    |> Enum.reduce(%{}, fn
      :auto_publish, acc ->
        Map.put(acc, "autoPublish", %{
          href: Routes.implementation_upload_path(conn, :create),
          method: "POST"
        })
      camel_case_string_action, acc -> Map.put(acc, camel_case_string_action, %{method: "POST"})
    end)
    |> then(&assign(conn, :actions, &1))
  end
end

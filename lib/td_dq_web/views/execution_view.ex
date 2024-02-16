defmodule TdDqWeb.ExecutionView do
  use TdDqWeb, :view

  alias TdDqWeb.QualityEventView
  alias TdDqWeb.RuleResultView
  alias TdDqWeb.RuleView

  def render("index.json", %{executions: executions}) do
    %{data: render_many(executions, __MODULE__, "execution.json")}
  end

  def render("show.json", %{execution: execution}) do
    %{data: render_one(execution, __MODULE__, "execution.json")}
  end

  def render("execution.json", %{execution: execution}) do
    json = Map.take(execution, [:id, :inserted_at])

    case embeddings(execution) do
      %{} = embeddings when embeddings != %{} -> Map.put(json, :_embedded, embeddings)
      _ -> json
    end
  end

  defp embeddings(%{} = execution) do
    execution
    |> Map.take([:rule, :implementation, :result, :quality_events, :group])
    |> Enum.sort_by(&rule_first/1)
    |> Enum.reduce(%{}, &put_embedding/2)
  end

  # The rule_type from the rule embedding needs to be passed into the
  # rule_result embedding, so we embed the rule first.
  defp rule_first({:rule, _}), do: 0
  defp rule_first(_), do: 1

  defp put_embedding({:implementation, %{} = implementation}, %{} = acc) do
    implementation =
      Map.take(implementation, [:id, :implementation_key, :rule_id, :minimum, :goal, :result_type])

    Map.put(acc, :implementation, implementation)
  end

  defp put_embedding({:result, %{} = result}, %{} = acc) do
    assigns =
      case acc do
        %{rule: rule} -> %{rule_result: result, rule: rule}
        _ -> %{rule_result: result}
      end

    result =
      result
      |> render_one(RuleResultView, "rule_result.json", assigns)
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Map.new()

    Map.put(acc, :result, result)
  end

  defp put_embedding({:rule, %{} = rule}, %{} = acc) do
    rule =
      rule
      |> render_one(RuleView, "embedded.json", %{rule: rule})
      |> Enum.reject(fn {_, v} -> is_nil(v) end)
      |> Map.new()

    Map.put(acc, :rule, rule)
  end

  defp put_embedding({:quality_events, events}, %{} = acc) when is_list(events) do
    status =
      case Enum.max_by(events, & &1.id, fn -> nil end) do
        %{type: status} -> status
        _ -> "PENDING"
      end

    events = render_many(events, QualityEventView, "quality_event.json")

    acc
    |> Map.put(:quality_events, events)
    |> Map.put(:status, status)
  end

  defp put_embedding({:group, %{df_content: %{} = df_content}}, %{} = acc) do
    Map.put(acc, :df_content, df_content)
  end

  defp put_embedding(_, acc), do: acc
end

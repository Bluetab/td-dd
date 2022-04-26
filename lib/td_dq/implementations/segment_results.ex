defmodule TdDq.Implementations.SegmentResults do
  @moduledoc """
  The Segment Results context.
  """

  alias TdDq.Implementations.SegmentResult
  alias TdDd.Repo
  alias TdDq.Rules.RuleResult

  @doc """
  Creates a segment result
  """

  def create_segments_result(%RuleResult{id: rule_result_id} = rule_result, %{
        "segments" => segments
      }) when is_list(segments) do

    {:ok, Enum.map(segments, fn segment ->
      SegmentResult.changeset(
        %SegmentResult{rule_result_id: rule_result_id},
        rule_result,
        segment
      )
      |> Repo.insert()
    end)}
  end

  def create_segment_result(_, _) do
    {:ok, []}
  end

end

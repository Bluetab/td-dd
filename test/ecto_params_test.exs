defmodule EctoParamsTest do
  use TdDd.DataCase

  import Ecto.Query

  @query """
  select id from data_structures where id = ANY(?) and system_id = ANY(ARRAY[$1::bigint[]])
  """

  test "A query fragment can reuse parameters" do
    q = "ds"
    |> with_cte("ds", as: fragment(@query, [123]))
    |> select([ds], ds.id)
    |> limit(10)
    |> IO.inspect()
    |> Repo.all()
    |> IO.inspect()
  end
end

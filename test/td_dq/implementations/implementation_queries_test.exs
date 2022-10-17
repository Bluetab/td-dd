defmodule TdDq.Implementations.ImplementationQueriesTest do
  use TdDd.DataCase

  alias TdDd.Repo
  alias TdDq.Implementations.ImplementationQueries

  describe "ImplementationQueries.implementation_ids_by_ref_query/1" do
    test "queries implementation ids with a given reference" do
      %{id: id1, implementation_ref: ref} = insert(:implementation)
      %{id: id2} = insert(:implementation, implementation_ref: ref)
      %{id: _id3} = insert(:implementation)

      q = ImplementationQueries.implementation_ids_by_ref_query(ref)
      assert_lists_equal(Repo.all(q), [id1, id2])
    end
  end
end

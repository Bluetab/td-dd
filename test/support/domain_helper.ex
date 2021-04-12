defmodule DomainHelper do
  @moduledoc """
  Support creation of domains in cache
  """

  import TdDd.Factory

  alias TdCache.TaxonomyCache

  def insert_domain do
    %{id: domain_id} = domain = build(:domain)
    TaxonomyCache.put_domain(domain)
    ExUnit.Callbacks.on_exit(fn -> TaxonomyCache.delete_domain(domain_id) end)
    domain
  end
end

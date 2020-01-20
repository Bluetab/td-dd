defmodule TdCx.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: TdCx.Repo

  alias TdCx.Sources.Jobs.Job
  alias TdCx.Sources.Source

  def source_factory do
    %Source{
      config: %{},
      external_id: "some external_id",
      secrets_key: "some secrets_key",
      type: "some type"
    }
  end

  def job_factory do
    %Job{
      source: build(:source)
    }
  end
end

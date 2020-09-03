defmodule TdCx.Factory do
  @moduledoc false

  use ExMachina.Ecto, repo: TdCx.Repo

  alias TdCx.Configurations.Configuration
  alias TdCx.Sources.Events.Event
  alias TdCx.Sources.Jobs.Job
  alias TdCx.Sources.Source

  def source_factory do
    %Source{
      config: %{},
      external_id: "some external_id",
      secrets_key: "some secrets_key",
      type: "some type",
      deleted_at: nil
    }
  end

  def job_factory do
    %Job{
      source: build(:source)
    }
  end

  def event_factory do
    %Event{
      job: build(:job),
      type: "init",
      message: "Message",
      inserted_at: DateTime.utc_now()
    }
  end

  def configuration_factory do
    %Configuration{
      type: "config",
      content: %{},
      external_id: "external_id"
    }
  end
end

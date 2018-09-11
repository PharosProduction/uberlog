defmodule Uberlog.Application do
  @moduledoc false

  use Application

  alias Uberlog.{Telegram, Slack}

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Telegram.Manager, []), 
      worker(Telegram.Formatter, [5, 10]), 
      worker(Telegram.Sender, [0, 5]),
      worker(Slack.Producer, []),
      worker(Slack.Formatter, [10, 5]),
      worker(Slack.Consumer, [10, 5]),
      worker(Slack.Pool, [10])
    ]

    Supervisor.start_link(
      children,
      strategy: :one_for_one,
      max_restarts: 5,
      max_seconds: 30,
      name: Uberlog.Supervisor
    )
  end
end
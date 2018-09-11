defmodule Uberlog.Slack.Consumer do
  @moduledoc false

  use GenStage
  
  alias Uberlog.Slack.{Formatter, Pool}

  ##### Public #####

  def start_link(max_demand, min_demand) do
    GenStage.start_link(__MODULE__, {max_demand, min_demand}, name: __MODULE__)
  end

  ##### Callbacks #####

  @impl true
  def init({max_demand, min_demand}) do
    {:consumer, %{}, subscribe_to: [
      {Formatter, max_demand: max_demand, min_demand: min_demand}
    ]}
  end

  @impl true
  def handle_events([], _from, interval), do: process_events([], interval)
  def handle_events(events, _from, state) do
    events
    |> Enum.filter(fn evt -> evt != :empty end)
    |> process_events(state)
  end

  ##### Private #####

  defp process_events([], state), do: {:noreply, [], state}
  defp process_events([{url, json} | events], state) do
    Pool.post(url, json)
    process_events(events, state)
  end
end
defmodule Uberlog.Slack.Formatter do
  @moduledoc false

  use GenStage

  alias Uberlog.Slack.{Producer, FormatHelper}

  ##### Public #####

  def start_link(max_demand, min_demand) do
    GenStage.start_link(__MODULE__, {max_demand, min_demand}, name: __MODULE__)
  end

  ##### Callbacks #####

  @impl true
  def init({max_demand, min_demand}) do
    {:producer_consumer, %{}, subscribe_to: [
      {Producer, max_demand: max_demand, min_demand: min_demand}
    ]}
  end

  @impl true
  def handle_events(events, _from, state) do
    events = Enum.map(events, &format_event/1)
    {:noreply, events, state}
  end

  ##### Private #####

  defp format_event({url, event}) do
    {url, FormatHelper.format_event(event)}
  end
end

defmodule Uberlog.Telegram.Sender do
  @moduledoc false

  use GenStage

  alias Uberlog.Telegram.Formatter

  ##### Public #####
  
  def start_link(min_demand, max_demand) do
    GenStage.start_link(__MODULE__, [min_demand, max_demand], name: __MODULE__)
  end

  ##### Callbacks #####

  @impl true
  def init([min_demand, max_demand]) do
    {:consumer, %{}, subscribe_to: [{Formatter, min_demand: min_demand, max_demand: max_demand}]}
  end

  @impl true
  def handle_events(events, _from, state), do: process_events(events, state)

  ##### Private #####

  defp process_events([], state), do: {:noreply, [], state}

  defp process_events([{sender, sender_args, text} | events], state) do
    apply(sender, :send_message, [text] ++ sender_args)
    process_events(events, state)
  end
end
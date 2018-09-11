defmodule Uberlog.Slack.Producer do
  @moduledoc false

  use GenStage

  ##### Public #####

  def start_link, do: GenStage.start_link(__MODULE__, :ok, name: __MODULE__)
  
  def add_event(event), do: GenStage.cast(__MODULE__, {:add, event})
  
  ##### Callbacks #####

  @impl true
  def init(:ok), do: {:producer, {:queue.new, 0}}

  @impl true
  def handle_cast({:add, event}, {queue, demand}) when demand > 0 do
    {:noreply, [event], {queue, demand - 1}}
  end
  def handle_cast({:add, event}, {queue, demand}) do
    {:noreply, [], {:queue.in(event, queue), demand}}
  end

  @impl true
  def handle_demand(incoming_demand, {queue, demand}) when incoming_demand > 0 do
    dispatch_events(queue, incoming_demand + demand, [])
  end

  ##### Private #####

  defp dispatch_events(queue, demand, events) when demand > 0 do
    case :queue.out(queue) do
      {:empty, queue} -> {:noreply, events, {queue, demand}}
      {{:value, event}, queue} -> dispatch_events(queue, demand - 1, [event|events])
    end
  end

  defp dispatch_events(queue, demand, events) do
    {:noreply, events, {queue, demand}}
  end
end

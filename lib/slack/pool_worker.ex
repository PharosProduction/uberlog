defmodule Uberlog.Slack.PoolWorker do
  @moduledoc false

  use GenServer

  ##### Public #####

  def start_link([]), do: GenServer.start_link(__MODULE__, [], [])

  @spec post(pid, String.t, String.t) :: atom
  def post(pid, url, json) do
    GenServer.call(pid, {:post, url, json}, :infinity)
  end

  ##### Callbacks #####

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:post, url, json}, _from, worker_state) do
    result = HTTPoison.post(url, json)
    {:reply, result, worker_state}
  end
end

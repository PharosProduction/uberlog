defmodule Uberlog.Slack.Logger do
  @moduledoc false

  use GenEvent
  
  alias Uberlog.Slack.Producer

  @env_webhook "SLACK_LOGGER_WEBHOOK_URL"
  @default_log_levels [:error]

  ##### Callbacks #####

  @impl true
  def init(__MODULE__), do: {:ok, %{levels: []}}
  def init({__MODULE__, levels}) when is_atom(levels) do
    {:ok, %{levels: [levels]}}
  end
  def init({__MODULE__, levels}) when is_list(levels) do
    {:ok, %{levels: levels}}
  end

  @impl true
  def handle_call(_request, state), do: {:ok, state}

  @impl true
  def handle_event({level, _pid, {_, message, _timestamp, detail}}, %{levels: []} = state) do
    levels = case get_env(:levels) do
      nil -> @default_log_levels
      levels -> levels
    end

    if level in levels do
      handle_event(level, message, detail)
    end

    {:ok, %{state | levels: levels}}
  end
  def handle_event({level, _pid, {_, message, _timestamp, detail}}, %{levels: levels} = state) do
    if level in levels do
      handle_event(level, message, detail)
    end

    {:ok, state}
  end
  def handle_event(:flush, state), do: {:ok, state}

  @impl true
  def handle_info(_message, state), do: {:ok, state}

  ##### Private #####

  defp get_url do
    case System.get_env(@env_webhook) do
      nil -> get_env(:slack)[:url]
      url -> url
    end
  end

  defp handle_event(level, message, detail) do
    {level, message, detail}
    |> send_event
  end

  defp send_event(event), do: Producer.add_event({get_url(), event})

  defp get_env(key, default \\ nil) do
    Application.get_env(Uberlog, key, Application.get_env(:uberlog, key, default))
  end
end

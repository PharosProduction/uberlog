defmodule Uberlog.Slack.FormatHelper do
  @moduledoc false

  def format_event({level, message, detail}) do
    Jason.encode!(%{
      text: "#{message}",
      attachments: [%{
        title: "Summary",
        fields: [
          %{title: "Level", value: level, short: true},
          %{title: "Application", value: detail[:application], short: true},
          %{title: "Module", value: detail[:module], short: true},
          %{title: "Function", value: detail[:function], short: true},
          %{title: "File", value: detail[:file], short: true},
          %{title: "RequestID", value: detail[:request_id], short: true}
        ]
      }]
    })
  end
end

defmodule BlogEngine.Queue do
  @moduledoc """
  Consumes ElasticMQ / SQS.

  Fiuu notifications arrive as envelopes published by WebhookEdge:

      %{"source" => "fiuu", "payload" => %{...callback fields...}, "received_at" => ...}

  Other jobs still use a top-level `"scope"` (`register`, `upgrade`).
  """

  use Broadway

  alias Broadway.Message

  def child_spec(opts) do
    %{
      id: Keyword.get(opts, :name, __MODULE__),
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  def start_link(opts) do
    sqs = Application.get_env(:blog_engine, :sqs, [])

    Broadway.start_link(__MODULE__,
      name: Keyword.get(opts, :name, __MODULE__),
      producer: [
        module:
          {BroadwaySQS.Producer,
           queue_url:
             Keyword.get(opts, :queue_url) || sqs[:queue_url] ||
               "http://localhost:9324/queue/queue1",
           config: [
             access_key_id: sqs[:access_key_id] || "x",
             secret_access_key: sqs[:secret_access_key] || "x",
             host: Keyword.get(opts, :host) || sqs[:host] || "localhost",
             port: Keyword.get(opts, :port) || sqs[:port] || "9324",
             scheme: sqs[:scheme] || "http://",
             region: sqs[:region] || "elasticmq"
           ]}
      ],
      processors: [
        default: [concurrency: 1]
      ],
      batchers: [
        default: [concurrency: 1, batch_size: 5]
      ]
    )
  end

  @impl true
  def handle_message(_, %Message{data: data} = message, _) do
    case Jason.decode(data) do
      {:ok, %{"source" => source, "payload" => payload}}
      when source in ["fiuu", "razer"] and is_map(payload) ->
        BlogEngine.FiuuNotification.process(payload)

        Message.update_data(message, fn _data -> "processed!" end)

      {:ok, processed} ->
        if "scope" in Map.keys(processed) do
          IO.inspect(processed)

          case processed["scope"] do
            "register" ->
              BlogEngine.Settings.post_registration(
                processed["user"],
                BlogEngine.Settings.get_sale!(processed["sale_id"]),
                processed["title"],
                processed["form_drp"]
              )

            "upgrade" ->
              BlogEngine.Settings.post_registration(
                processed["user"],
                BlogEngine.Settings.get_sale!(processed["sale_id"]),
                processed["title"],
                processed["form_drp"]
              )

            _ ->
              nil
          end

          Message.update_data(message, fn _data -> "processed!" end)
        else
          Message.update_data(message, fn _data -> "scope: not present" end)
        end

      {:error, _message} ->
        Message.update_data(message, fn _data -> "scope: not present" end)
    end
  end

  @impl true
  def handle_batch(_, messages, _, _) do
    list = messages |> Enum.map(fn e -> e.data end)

    IO.inspect(list,
      label: "Got batch of finished jobs from processors, sending ACKs to SQS as a batch."
    )

    messages
  end
end

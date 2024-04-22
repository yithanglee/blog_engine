defmodule BlogEngine.Queue do
  use Broadway

  alias Broadway.Message

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module:
          {BroadwaySQS.Producer,
           queue_url: "http://localhost:9324/queue/queue1",
           config: [
             access_key_id: "x",
             secret_access_key: "x",
             host: "localhost",
             port: "9324",
             scheme: "http://",
             region: "elasticmq"
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
    case message.data |> Jason.decode() |> IO.inspect() do
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

            # need to get the device name and its current hwaddrss
            _ ->
              nil
          end

          # process the data here
          message
          |> Message.update_data(fn _data ->
            "processed!"
          end)
        else
          message
          |> Message.update_data(fn _data -> "scope: not present" end)
        end

      {:error, _message} ->
        message
        |> Message.update_data(fn _data -> "scope: not present" end)
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

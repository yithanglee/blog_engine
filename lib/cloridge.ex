defmodule CloridgeAPI do
  @api_url "https://bprod.cloridge.com/api/open/v1/"

  def initial_setup(deviceId \\ "YQWIFIUKF010501") do
    headers = [
      {"Content-Type", "multipart/form-data"}
    ]

    # JSON payload for the 'params' field
    params_json =
      Jason.encode!(%{
        "s1" => "0",
        "s2" => "040",
        "s3" => "300",
        "t1" => "0",
        "t2" => "018",
        "t3" => "110"
      })

    body =
      {:multipart,
       [
         {"appKey", Application.get_env(:blog_engine, :cloridge)[:key]},
         {"appSecret", Application.get_env(:blog_engine, :cloridge)[:secret]},
         {"params", params_json},
         {"deviceId", deviceId}
       ]}

    case HTTPoison.post(@api_url <> "message/params", body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        IO.inspect(body, label: "Response body")
        {:ok, body}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        IO.puts("Request failed with status: #{status_code}")
        {:error, status_code}

      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.puts("Request failed due to: #{reason}")
        {:error, reason}
    end
  end

  def get_message_status(deviceId \\ "YQWIFIUKF010501") do
    params = [
      {"appKey", Application.get_env(:blog_engine, :cloridge)[:key]},
      {"appSecret", Application.get_env(:blog_engine, :cloridge)[:secret]},
      {"deviceId", deviceId}
    ]

    # Convert params to query string
    query_string = URI.encode_query(params)

    full_url = "#{@api_url}message/status?#{query_string}"

    case HTTPoison.get(full_url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        IO.inspect(body, label: "Response body")
        {:ok, body}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        IO.puts("Request failed with status: #{status_code}")
        {:error, status_code}

      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.puts("Request failed due to: #{reason}")
        {:error, reason}
    end
  end

  def send_message(pulseCount, deviceId \\ "YQWIFIUKF010501") do
    headers = [
      {"Content-Type", "multipart/form-data"}
    ]

    body =
      {:multipart,
       [
         {"appKey", Application.get_env(:blog_engine, :cloridge)[:key]},
         {"appSecret", Application.get_env(:blog_engine, :cloridge)[:secret]},
         {"messageType", "pulse"},
         {"messageCount", "#{pulseCount}"},
         {"deviceId", deviceId}
       ]}

    case HTTPoison.post(@api_url <> "message/send", body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        IO.inspect(body, label: "Response body")
        {:ok, body}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        IO.puts("Request failed with status: #{status_code}")
        {:error, status_code}

      {:error, %HTTPoison.Error{reason: reason}} ->
        IO.puts("Request failed due to: #{reason}")
        {:error, reason}
    end
  end
end

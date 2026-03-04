defmodule BlogEngineWeb.Router do
  use BlogEngineWeb, :router

  if Mix.env() == :dev do
    # If using Phoenix
    forward "/sent_emails", Bamboo.SentEmailViewerPlug
  end

  @content_security_policy (case Mix.env() do
                              # :prod  -> "default-src 'self'"

                              # _ -> "default-src 'self' 'unsafe-eval'"

                              _ ->
                                "default-src 'self' 'unsafe-inline' fonts.gstatic.com; img-src 'self' blob data: ; style-src 'self' 'unsafe-inline' fonts.googleapis.com fonts.gstatic.com;"
                            end)
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    # plug :put_secure_browser_headers, %{"content-security-policy" => @content_security_policy}
  end

  pipeline :plain_api do
    plug :accepts, ["json"]
  end

  pipeline :svt_api do
    plug :accepts, ["json"]

    plug CORSPlug,
      origin: [
        "https://fonts.gstatic.com",
        "https://svt_blog.damienslab.com",
        "http://svt_blog.damienslab.com",
        "http://admin.djtech4u.com",
        "https://admin.djtech4u.com",
        "http://localhost:5173",
        "http://localhost:5174",
        "http://localhost:2578",
        "http://localhost:3000",
        "http://localhost:8080"
      ]

    plug(BlogEngine.ApiAuthorization)
  end

  pipeline :browser_blank do
    plug :accepts, ["html"]
  end

  pipeline :api do
    plug :accepts, ["json"]
    # plug :fetch_session
    # plug :protect_from_forgery

    plug CORSPlug,
      origin: [
        "https://fonts.gstatic.com",
        "https://svt_blog.damienslab.com",
        "http://svt_blog.damienslab.com",
        "http://admin.djtech4u.com",
        "https://admin.djtech4u.com",
        "http://localhost:5173",
        "http://localhost:5174",
        "http://localhost:2578",
        "http://localhost:3000"
      ]

    plug(BlogEngine.ApiAuthorization)
  end

  scope "/api", BlogEngineWeb do
    pipe_through :browser_blank

    post "/callback/razer", PageController, :notification
    post "/notification/razer", PageController, :notification
  end

  scope "/ngrok", BlogEngineWeb do
    pipe_through :plain_api
    options("/webhook", ApiController, :ngrok_get)
    get("/webhook", ApiController, :ngrok_get)
    post("/webhook", ApiController, :ngrok_post)
  end

  scope "/iot", BlogEngineWeb do
    pipe_through :plain_api
    get "/stream", ApiController, :stream_get
    options("/:webhook", ApiController, :get)

    get "/webhook", ApiController, :get
    post "/webhook", ApiController, :post

    # ESP32 HTTP polling endpoints (existing)
    get "/poll/:device_id", ApiController, :esp32_poll
    get "/stream/:device_id", ApiController, :esp32_stream
    post "/complete/:device_id", ApiController, :esp32_complete

    # A7670C cellular device endpoints
    post "/a7670c/join", ApiController, :a7670c_join
    get "/a7670c/poll/:device_id", ApiController, :a7670c_poll
    post "/a7670c/reading/:device_id", ApiController, :a7670c_reading
    get "/a7670c/commands/:device_id", ApiController, :a7670c_commands

    # OTA update endpoints
    post "/ota/trigger/:device_id", ApiController, :trigger_ota_update
    get "/ota/status/:device_id", ApiController, :get_ota_status
    post "/ota/batch", ApiController, :batch_ota_update
    get "/ota/versions", ApiController, :list_firmware_versions
  end

  scope "/firmware", BlogEngineWeb do
    pipe_through :plain_api

    # Check for firmware updates
    get "/check/:device_id", PageController, :check_firmware_version

    # Download firmware binary
    get "/:device_id/:version", PageController, :firmware_download

    # OTA status reporting from devices
    post "/status/:device_id", ApiController, :ota_status_report
  end

  scope "/cloridge", BlogEngineWeb do
    pipe_through :svt_api
    get "/stream", ApiController, :stream_get
    options("/:webhook", ApiController, :get)

    get "/webhook", ApiController, :get
    post "/webhook", ApiController, :post
  end

  scope "/svt_api", BlogEngineWeb do
    pipe_through :svt_api
    get "/stream", ApiController, :stream_get
    options("/:webhook", ApiController, :get)

    get "/webhook", ApiController, :get
    post "/webhook", ApiController, :post
    options("/:model", ApiController, :datatable)
    get("/:model", ApiController, :datatable)
    post("/:model", ApiController, :form_submission)

    delete("/:model/:id", ApiController, :delete_data)

    options("/*path", PageController, :index)
  end

  scope "/api", BlogEngineWeb do
    pipe_through :plain_api
    post "/payment/razer", ApiController, :razer_payment
    post "/payment/billplz", ApiController, :payment
    post "/payment/ipay88", ApiController, :ipay88_payment
  end

  scope "/api", BlogEngineWeb do
    pipe_through :api

    post "/webhook/login", ApiController, :post
  end

  scope "/api", BlogEngineWeb do
    pipe_through :api
    get "/stream", ApiController, :stream_get
    options("/:webhook", ApiController, :get)

    get "/webhook", ApiController, :get
    post "/webhook", ApiController, :post
    options("/:model", ApiController, :datatable)
    get("/:model", ApiController, :datatable)
    post("/:model", ApiController, :form_submission)
    delete("/:model/:id", ApiController, :delete_data)
  end

  scope "/html/:lang", BlogEngineWeb do
    pipe_through [:browser]
    get "/*path", PageController, :html
  end

  scope "/", BlogEngineWeb do
    pipe_through :browser_blank
    get "/subscription_payment", PageController, :subscription_payment
    get "/test_razer", PageController, :razer_payment
    post "/test_razer", PageController, :razer_payment
    post "/thank_you", PageController, :thank_you
  end

  scope "/", BlogEngineWeb do
    pipe_through :browser

    get "/admin_override", PageController, :admin_override
    get "/", PageController, :index
    get "/pdf_preview", PageController, :pdf_preview
    get "/pdf", PageController, :pdf
    get "/log2in", PageController, :login
    post "/auth", PageController, :authenticate
    post "/thank_you", PageController, :thank_you
    get "/thank_you", PageController, :thank_you
    get "/*path", PageController, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", BlogEngineWeb do
  #   pipe_through :api
  # end
end

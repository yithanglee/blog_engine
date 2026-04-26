defmodule BlogEngine.Mailer do
  use Bamboo.Mailer, otp_app: :blog_engine

  def send_email_for_org(email) do
    adapter_config = get_smtp_config_for_org() |> IO.inspect()

    deliver_now(email, config: adapter_config) |> IO.inspect()
  end

  defp get_smtp_config_for_org() do
    %{
      adapter: Bamboo.SMTPAdapter,
      server: "localhost",
      hostname: "mail.damienslab.com",
      port: 25,
      username: "ubuntu",
      password: "unwanted2",
      tls: :always,
      allowed_tls_versions: [:"tlsv1.2"],
      tls_log_level: :error,
      tls_verify: :verify_none,
      ssl: false,
      retries: 1,
      no_mx_lookups: false,
      auth: :if_available
    }
  end
end


defmodule BlogEngine.Email do
  import Bamboo.Email
  import Bamboo.Phoenix

  use Bamboo.Phoenix, view: BlogEngineWeb.EmailView

  def custom_email(user_email, from_email, subject, html) do
    # Build your default email then customize for welcome
    base_email(from_email)
    |> to(user_email)
    |> subject(subject)
    |> put_header("Reply-To", from_email)
    |> render("custom_email.html", html: html)
  end

  def verification_email(user_email, from_email, brand_map, user_map \\ %{name: "there"}) do
    base_email(from_email)
    |> to(user_email)
    |> subject("Verification")
    |> put_header("Reply-To", from_email)
    |> render("verification_email.html", brand: brand_map, user: user_map)
  end

  def password_reset_email(user_email, from_email, brand_map, user_map \\ %{name: "there"}) do
    base_email(from_email)
    |> to(user_email)
    |> subject("Reset your password")
    |> put_header("Reply-To", from_email)
    |> render("password_reset_email.html", brand: brand_map, user: user_map)
  end

  def welcome_email(user_email, from_email, brand_map, user_map \\ %{name: "John Doe"}) do
    # Build your default email then customize for welcome
    base_email(from_email)
    |> to(user_email)
    |> subject("Welcome")
    |> put_header("Reply-To", from_email)
    |> render("welcome.html", brand: brand_map, user: user_map)
  end

  defp base_email(from_email) do
    new_email()
    |> from(from_email)
    |> put_html_layout({BlogEngineWeb.LayoutView, "email.html"})

    # Set default text layout
    # |> put_text_layout({BlogEngineWeb.LayoutView, "email.text"})
  end

  def send_verification_email(user_email, from_email, brand_map, user_map) do
    verification_email(user_email, from_email, brand_map, user_map)
    |> BlogEngine.Mailer.send_email_for_org()
  end

  def send_password_reset_email(user_email, from_email, brand_map, user_map) do
    password_reset_email(user_email, from_email, brand_map, user_map)
    |> BlogEngine.Mailer.send_email_for_org()
  end
end

# BlogEngine.Email.welcome_email |> BlogEngine.Mailer.deliver_now

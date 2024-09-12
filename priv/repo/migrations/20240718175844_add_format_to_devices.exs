defmodule BlogEngine.Repo.Migrations.AddFormatToDevices do
  use Ecto.Migration

  def change do
    alter table("devices") do
       add :format, :string, default: "pwm"
    end
  end
end

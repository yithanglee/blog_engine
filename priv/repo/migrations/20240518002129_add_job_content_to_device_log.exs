defmodule BlogEngine.Repo.Migrations.AddJobContentToDeviceLog do
  use Ecto.Migration

  def change do
    alter table("device_logs") do
       add :job_content, :binary
    end
  end
end

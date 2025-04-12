defmodule BlogEngine.Repo.Migrations.AddRoundDownKeepPendingTaskToDevices do
  use Ecto.Migration

  def change do
    alter table("devices") do
      add :is_round_down, :boolean, default: true 
      add :keep_pending_task, :boolean, default: true
    end
  end
end

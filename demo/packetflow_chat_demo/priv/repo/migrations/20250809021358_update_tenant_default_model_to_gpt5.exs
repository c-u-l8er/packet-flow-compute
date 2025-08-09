defmodule PacketflowChatDemo.Repo.Migrations.UpdateTenantDefaultModelToGpt5 do
  use Ecto.Migration

    def up do
    # Update existing tenants to use GPT-5 as default model
    # This migration updates tenants that are still using older models
    execute """
    UPDATE tenants
    SET default_model = 'gpt-5'
    WHERE default_model IN ('gpt-3.5-turbo', 'gpt-4', 'gpt-4-turbo', 'gpt-4o')
    """

    # Also update any sessions that might be using old models
    execute """
    UPDATE chat_sessions
    SET model = 'gpt-5'
    WHERE model IN ('gpt-3.5-turbo', 'gpt-4', 'gpt-4-turbo', 'gpt-4o')
    """
  end

  def down do
    # Revert to gpt-4o for rollback (most recent older model)
    execute """
    UPDATE tenants
    SET default_model = 'gpt-4o'
    WHERE default_model LIKE 'gpt-5%'
    """

    execute """
    UPDATE chat_sessions
    SET model = 'gpt-4o'
    WHERE model LIKE 'gpt-5%'
    """
  end
end

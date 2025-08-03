defmodule PacketflowChat.Repo do
  use Ecto.Repo,
    otp_app: :packetflow_chat,
    adapter: Ecto.Adapters.Postgres
end

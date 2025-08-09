defmodule PacketflowChatDemo.Repo do
  use Ecto.Repo,
    otp_app: :packetflow_chat_demo,
    adapter: Ecto.Adapters.Postgres
end

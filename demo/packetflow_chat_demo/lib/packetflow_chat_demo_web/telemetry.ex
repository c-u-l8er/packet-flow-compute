defmodule PacketflowChatDemoWeb.Telemetry do
  use Supervisor

  def start_link(_arg) do
    children = [
      # Add telemetry handlers here if needed
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Add telemetry handlers here if needed
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end

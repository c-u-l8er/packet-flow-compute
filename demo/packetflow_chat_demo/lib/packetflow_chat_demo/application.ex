defmodule PacketflowChatDemo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the database repository
      PacketflowChatDemo.Repo,

      # Start PubSub for streaming support
      {Phoenix.PubSub, name: PacketflowChatDemo.PubSub},

      # Start the chat reactor
      PacketflowChatDemo.ChatReactor,

      # Start the Phoenix endpoint
      PacketflowChatDemoWeb.Endpoint,

      # Start the telemetry supervisor
      PacketflowChatDemoWeb.Telemetry
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PacketflowChatDemo.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

defmodule PacketflowChatDemo.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the chat reactor
      PacketflowChatDemo.ChatReactor
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PacketflowChatDemo.Supervisor]
    {:ok, pid} = Supervisor.start_link(children, opts)

    # Start the web server manually
    start_web_server()

    {:ok, pid}
  end

  defp start_web_server do
    # Start Cowboy HTTP server with our Plug
    {:ok, _} = :cowboy.start_clear(:http,
      [port: 4000],
      %{env: %{dispatch: dispatch_table()}}
    )
  end

  defp dispatch_table do
    :cowboy_router.compile([
      {:_, [
        {"/", PacketflowChatDemo.Web, []},
        {"/api/[...]", PacketflowChatDemo.Web, []}
      ]}
    ])
  end
end

defmodule PacketflowChatDemo.ChatReactor do
  @moduledoc """
  Chat Reactor - Wraps the PacketFlow ChatReactor for easy integration
  """

  use GenServer
  require Logger

  # ============================================================================
  # CLIENT API
  # ============================================================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def send_message(user_id, message, session_id \\ generate_session_id()) do
    GenServer.call(__MODULE__, {:send_message, user_id, message, session_id})
  end

  def get_history(user_id, session_id) do
    GenServer.call(__MODULE__, {:get_history, user_id, session_id})
  end

  def update_config(user_id, config) do
    GenServer.call(__MODULE__, {:update_config, user_id, config})
  end

  def get_sessions do
    GenServer.call(__MODULE__, :get_sessions)
  end

  # ============================================================================
  # SERVER CALLBACKS
  # ============================================================================

  @impl true
  def init(_opts) do
    Logger.info("Starting ChatReactor...")

    # Start the PacketFlow ChatReactor using GenServer.start_link
    case PacketflowChatDemo.ChatSystem.ChatReactor.start_link() do
      {:ok, reactor_pid} ->
        Logger.info("ChatReactor started successfully")
        {:ok, %{reactor_pid: reactor_pid}}

      {:error, reason} ->
        Logger.error("Failed to start ChatReactor: #{reason}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:send_message, user_id, message, session_id}, _from, state) do
    # Create intent with context
    _context = PacketflowChatDemo.ChatSystem.ChatContext.new(%{
      user_id: user_id,
      session_id: session_id,
      capabilities: [PacketflowChatDemo.ChatSystem.ChatCap.send_message],
      model_config: %{model: "gpt-3.5-turbo", temperature: 0.7}
    })

    intent = PacketflowChatDemo.ChatSystem.SendMessageIntent.new(user_id, message, session_id)

    # Send intent to reactor
    Logger.info("Sending intent to reactor: #{inspect(intent)}")
    case GenServer.call(state.reactor_pid, {:process_intent, intent}, 5000) do
      {:ok, effects} ->
        Logger.info("Received effects: #{inspect(effects)}")
        case effects do
          [effect] ->
            case effect do
              %PacketflowChatDemo.ChatSystem.ChatEffect{type: :message_sent, data: data} ->
                {:reply, {:ok, data}, state}

              %PacketflowChatDemo.ChatSystem.ChatEffect{type: :error, data: data} ->
                {:reply, {:error, data}, state}
            end
          _ ->
            {:reply, {:error, %{error_code: :unexpected_effects, message: "Unexpected effects format: #{inspect(effects)}"}}, state}
        end

      {:error, reason} ->
        {:reply, {:error, %{error_code: :reactor_error, message: reason}}, state}
    end
  end

  def handle_call({:get_history, user_id, session_id}, _from, state) do
    # Create intent with context
    _context = PacketflowChatDemo.ChatSystem.ChatContext.new(%{
      user_id: user_id,
      session_id: session_id,
      capabilities: [PacketflowChatDemo.ChatSystem.ChatCap.view_history],
      model_config: %{}
    })

    intent = PacketflowChatDemo.ChatSystem.GetHistoryIntent.new(user_id, session_id)

    # Send intent to reactor
    case GenServer.call(state.reactor_pid, {:process_intent, intent}, 5000) do
      {:ok, effects} ->
        case effects do
          [effect] ->
            case effect do
              %PacketflowChatDemo.ChatSystem.ChatEffect{type: :history_retrieved, data: data} ->
                {:reply, {:ok, data}, state}

              %PacketflowChatDemo.ChatSystem.ChatEffect{type: :error, data: data} ->
                {:reply, {:error, data}, state}
            end
          _ ->
            {:reply, {:error, %{error_code: :unexpected_effects, message: "Unexpected effects format"}}, state}
        end

      {:error, reason} ->
        {:reply, {:error, %{error_code: :reactor_error, message: reason}}, state}
    end
  end

  def handle_call({:update_config, user_id, config}, _from, state) do
    # Create intent with context
    _context = PacketflowChatDemo.ChatSystem.ChatContext.new(%{
      user_id: user_id,
      session_id: "admin",
      capabilities: [PacketflowChatDemo.ChatSystem.ChatCap.admin],
      model_config: %{}
    })

    intent = PacketflowChatDemo.ChatSystem.AdminConfigIntent.new(user_id, config)

    # Send intent to reactor
    case GenServer.call(state.reactor_pid, {:process_intent, intent}, 5000) do
      {:ok, effects} ->
        case effects do
          [effect] ->
            case effect do
              %PacketflowChatDemo.ChatSystem.ChatEffect{type: :config_updated, data: data} ->
                {:reply, {:ok, data}, state}

              %PacketflowChatDemo.ChatSystem.ChatEffect{type: :error, data: data} ->
                {:reply, {:error, data}, state}
            end
          _ ->
            {:reply, {:error, %{error_code: :unexpected_effects, message: "Unexpected effects format"}}, state}
        end

      {:error, reason} ->
        {:reply, {:error, %{error_code: :reactor_error, message: reason}}, state}
    end
  end

  def handle_call(:get_sessions, _from, state) do
    # Get reactor state to access sessions
    case GenServer.call(state.reactor_pid, :get_state, 5000) do
      {:ok, %{sessions: sessions}} ->
        {:reply, {:ok, sessions}, state}

      {:error, reason} ->
        {:reply, {:error, %{error_code: :state_error, message: reason}}, state}
    end
  end

  @impl true
  def handle_info({:packetflow_effect, effect}, state) do
    Logger.info("Received effect: #{inspect(effect)}")
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    Logger.info("Stopping ChatReactor...")
    GenServer.stop(state.reactor_pid)
    :ok
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp generate_session_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end

defmodule PacketFlow.Component.Interface do
  @moduledoc """
  Standard interfaces for PacketFlow components

  This module defines the core interfaces that all PacketFlow components
  should implement to ensure consistent behavior and interoperability.
  """

  @doc """
  Component initialization interface (use component-specific init functions to avoid GenServer conflicts)
  """
  @callback component_init(config :: map()) :: {:ok, state :: term()} | {:error, reason :: term()}

  @doc """
  Component state interface - get current state
  """
  @callback get_state() :: term()

  @doc """
  Component state interface - update state
  """
  @callback update_state(new_state :: term()) :: :ok | {:error, reason :: term()}

  @doc """
  Component communication interface - send message
  """
  @callback send_message(target :: atom(), message :: term()) :: :ok | {:error, reason :: term()}

  @doc """
  Component communication interface - handle message
  """
  @callback handle_message(message :: term(), state :: term()) ::
    {:ok, new_state :: term()} |
    {:ok, new_state :: term(), reply :: term()} |
    {:error, reason :: term()}

  @doc """
  Component monitoring interface - health check
  """
  @callback health_check() :: :healthy | :unhealthy | :degraded

  @doc """
  Component monitoring interface - get metrics
  """
  @callback get_metrics() :: map()

  @doc """
  Component configuration interface - get configuration
  """
  @callback get_config() :: map()

  @doc """
  Component configuration interface - update configuration
  """
  @callback update_config(new_config :: map()) :: :ok | {:error, reason :: term()}

  @doc """
  Component lifecycle interface - start component
  """
  @callback start_component(config :: map()) :: {:ok, pid()} | {:error, reason :: term()}

  @doc """
  Component lifecycle interface - stop component
  """
  @callback stop_component() :: :ok | {:error, reason :: term()}

  @doc """
  Component dependency interface - get dependencies
  """
  @callback get_dependencies() :: [atom()]

  @doc """
  Component dependency interface - validate dependencies
  """
  @callback validate_dependencies() :: :ok | {:error, [atom()]}

  @doc """
  Component capability interface - get required capabilities
  """
  @callback get_required_capabilities() :: [term()]

  @doc """
  Component capability interface - get provided capabilities
  """
  @callback get_provided_capabilities() :: [term()]

  @optional_callbacks [
    component_init: 1,
    get_state: 0,
    update_state: 1,
    send_message: 2,
    handle_message: 2,
    health_check: 0,
    get_metrics: 0,
    get_config: 0,
    update_config: 1,
    start_component: 1,
    stop_component: 0,
    get_dependencies: 0,
    validate_dependencies: 0,
    get_required_capabilities: 0,
    get_provided_capabilities: 0
  ]

  @doc """
  Macro to implement standard component interface behaviors
  """
  defmacro __using__(_opts \\ []) do
    quote do
      @behaviour PacketFlow.Component.Interface

      # Default implementations
      def component_init(config) do
        {:ok, %{config: config, state: %{}, started_at: System.system_time(:millisecond)}}
      end

      def get_state() do
        GenServer.call(__MODULE__, :get_state)
      end

      def update_state(new_state) do
        GenServer.call(__MODULE__, {:update_state, new_state})
      end

      def send_message(target, message) do
        case Process.whereis(target) do
          nil -> {:error, :target_not_found}
          pid ->
            send(pid, {:component_message, __MODULE__, message})
            :ok
        end
      end

      def handle_message(message, state) do
        # Default message handling - log and continue
        require Logger
        Logger.info("Component #{__MODULE__} received message: #{inspect(message)}")
        {:ok, state}
      end

      def health_check() do
        case Process.whereis(__MODULE__) do
          nil -> :unhealthy
          pid when is_pid(pid) ->
            if Process.alive?(pid) do
              :healthy
            else
              :unhealthy
            end
        end
      end

      def get_metrics() do
        %{
          component: __MODULE__,
          health: health_check(),
          uptime: System.system_time(:millisecond) - get_started_time(),
          message_count: get_message_count()
        }
      end

      def get_config() do
        GenServer.call(__MODULE__, :get_config)
      end

      def update_config(new_config) do
        GenServer.call(__MODULE__, {:update_config, new_config})
      end

      def start_component(config) do
        GenServer.start_link(__MODULE__, config, name: __MODULE__)
      end

      def stop_component() do
        GenServer.stop(__MODULE__)
      end

      def get_dependencies() do
        []
      end

      def validate_dependencies() do
        dependencies = get_dependencies()
        missing = Enum.filter(dependencies, fn dep ->
          case Process.whereis(dep) do
            nil -> true
            _pid -> false
          end
        end)

        if Enum.empty?(missing) do
          :ok
        else
          {:error, missing}
        end
      end

      def get_required_capabilities() do
        []
      end

      def get_provided_capabilities() do
        []
      end

      # Private helper functions
      defp get_started_time() do
        case GenServer.call(__MODULE__, :get_started_time) do
          {:ok, time} -> time
          _ -> System.system_time(:millisecond)
        end
      end

      defp get_message_count() do
        case GenServer.call(__MODULE__, :get_message_count) do
          {:ok, count} -> count
          _ -> 0
        end
      end

      # Allow overriding default implementations
      defoverridable [
        component_init: 1,
        get_state: 0,
        update_state: 1,
        send_message: 2,
        handle_message: 2,
        health_check: 0,
        get_metrics: 0,
        get_config: 0,
        update_config: 1,
        start_component: 1,
        stop_component: 0,
        get_dependencies: 0,
        validate_dependencies: 0,
        get_required_capabilities: 0,
        get_provided_capabilities: 0
      ]
    end
  end

  @doc """
  Validate that a module implements the component interface
  """
  def validate_component_interface(module) do
    required_functions = [
      {:component_init, 1},
      {:get_state, 0},
      {:update_state, 1},
      {:health_check, 0}
    ]

    missing = Enum.filter(required_functions, fn {func, arity} ->
      not function_exported?(module, func, arity)
    end)

    if Enum.empty?(missing) do
      :ok
    else
      {:error, {:missing_functions, missing}}
    end
  end

  @doc """
  Get component interface metadata
  """
  def get_interface_metadata(module) do
    attributes = module.module_info(:attributes)
    behaviours = List.flatten(attributes[:behaviour] || [])

    %{
      module: module,
      behaviours: behaviours,
      functions: module.module_info(:exports),
      implements_component_interface: validate_component_interface(module) == :ok
    }
  end
end

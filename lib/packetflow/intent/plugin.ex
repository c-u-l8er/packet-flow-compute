defmodule PacketFlow.Intent.Plugin do
  @moduledoc """
  Plugin system for intent extensions

  This module provides a framework for creating custom intent types,
  routing logic, validation logic, transformation logic, and composition patterns.
  """

  @doc """
  Define an intent plugin with custom behavior

  ## Example
  ```elixir
  defintent_plugin MyCustomIntentPlugin do
    @plugin_type :intent_validation
    @priority 10

    def validate(intent) do
      case intent.type do
        "FileReadIntent" ->
          validate_file_read(intent)
        "UserIntent" ->
          validate_user_intent(intent)
        _ ->
          {:ok, intent}
      end
    end

    def transform(intent) do
      # Transform intent as needed
      {:ok, intent}
    end

    def route(intent, targets) do
      # Custom routing logic
      {:ok, targets}
    end

    def compose(intents, strategy) do
      # Custom composition logic
      {:ok, intents}
    end

    defp validate_file_read(intent) do
      case intent.payload.path do
        path when is_binary(path) and byte_size(path) > 0 ->
          {:ok, intent}
        _ ->
          {:error, :invalid_file_path}
      end
    end

    defp validate_user_intent(intent) do
      case intent.payload.user_id do
        user_id when is_binary(user_id) and byte_size(user_id) > 0 ->
          {:ok, intent}
        _ ->
          {:error, :invalid_user_id}
      end
    end
  end
  """
  defmacro defintent_plugin(name, do: body) do
    quote do
      defmodule unquote(name) do
        @behaviour PacketFlow.Intent.Plugin.Behaviour

        # Plugin configuration
        @plugin_type :intent_plugin
        @priority 5

        unquote(body)

        # Default implementations
        def validate(intent) do
          {:ok, intent}
        end

        def transform(intent) do
          {:ok, intent}
        end

        def route(intent, targets) do
          {:ok, targets}
        end

        def compose(intents, strategy) do
          {:ok, intents}
        end

        def plugin_type do
          @plugin_type
        end

        def priority do
          @priority
        end
      end
    end
  end

  @doc """
  Register an intent plugin with the system

  ## Example
  ```elixir
  PacketFlow.Intent.Plugin.register_plugin(MyCustomIntentPlugin)
  ```
  """
  def register_plugin(plugin_module) do
    # For now, just store in process dictionary for testing
    Process.put(:intent_plugins, [plugin_module | get_plugins()])
    {:ok, plugin_module}
  end

  @doc """
  Unregister an intent plugin from the system

  ## Example
  ```elixir
  PacketFlow.Intent.Plugin.unregister_plugin(MyCustomIntentPlugin)
  ```
  """
  def unregister_plugin(plugin_module) do
    # For now, just remove from process dictionary for testing
    current_plugins = get_plugins()
    updated_plugins = Enum.reject(current_plugins, fn plugin -> plugin == plugin_module end)
    Process.put(:intent_plugins, updated_plugins)
    {:ok, plugin_module}
  end

  @doc """
  Get all registered intent plugins

  ## Example
  ```elixir
  plugins = PacketFlow.Intent.Plugin.get_plugins()
  ```
  """
  def get_plugins do
    # For now, just get from process dictionary for testing
    Process.get(:intent_plugins, [])
  end

  @doc """
  Get plugins by type

  ## Example
  ```elixir
  validation_plugins = PacketFlow.Intent.Plugin.get_plugins_by_type(:intent_validation)
  transformation_plugins = PacketFlow.Intent.Plugin.get_plugins_by_type(:intent_transformation)
  ```
  """
  def get_plugins_by_type(plugin_type) do
    get_plugins()
    |> Enum.filter(fn plugin -> plugin.plugin_type() == plugin_type end)
    |> Enum.sort_by(& &1.priority(), :desc)
  end

  @doc """
  Create a custom intent type

  ## Example
  ```elixir
  defcustom_intent_type FileOperationIntent do
    @intent_type :file_operation
    @capabilities [FileCap.read, FileCap.write]

    def new(operation, path, user_id) do
      %{
        type: @intent_type,
        operation: operation,
        path: path,
        user_id: user_id,
        capabilities: [FileCap.read(path), FileCap.write(path)]
      }
    end

    def validate(intent) do
      case intent.operation do
        :read -> validate_read_operation(intent)
        :write -> validate_write_operation(intent)
        _ -> {:error, :unsupported_operation}
      end
    end

    defp validate_read_operation(intent) do
      case File.exists?(intent.path) do
        true -> {:ok, intent}
        false -> {:error, :file_not_found}
      end
    end

    defp validate_write_operation(intent) do
      case File.writable?(Path.dirname(intent.path)) do
        true -> {:ok, intent}
        false -> {:error, :directory_not_writable}
      end
    end
  end
  """
  defmacro defcustom_intent_type(name, do: body) do
    quote do
      defmodule unquote(name) do
        @behaviour PacketFlow.Intent.Plugin.CustomType

        # Intent type configuration
        @intent_type :custom_intent
        @capabilities []

        unquote(body)

        # Default implementations
        def intent_type do
          @intent_type
        end

        def capabilities do
          @capabilities
        end

        def validate(intent) do
          {:ok, intent}
        end

        def transform(intent) do
          {:ok, intent}
        end
      end
    end
  end

  @doc """
  Create a custom routing strategy

  ## Example
  ```elixir
  defcustom_routing_strategy LoadBalancedRouting do
    @strategy_type :load_balanced
    @targets [:reactor1, :reactor2, :reactor3]

    def route(intent, available_targets) do
      # Load balancing logic
      target = select_target(available_targets)
      {:ok, target}
    end

    defp select_target(targets) do
      # Simple round-robin selection
      Enum.random(targets)
    end
  end
  """
  defmacro defcustom_routing_strategy(name, do: body) do
    quote do
      defmodule unquote(name) do
        @behaviour PacketFlow.Intent.Plugin.RoutingStrategy

        # Routing strategy configuration
        @strategy_type :custom_routing
        @targets []

        unquote(body)

        # Default implementations
        def strategy_type do
          @strategy_type
        end

        def targets do
          @targets
        end

        def route(intent, available_targets) do
          # Default routing logic
          case available_targets do
            [target | _] -> {:ok, target}
            [] -> {:error, :no_available_targets}
          end
        end
      end
    end
  end

  @doc """
  Create a custom composition pattern

  ## Example
  ```elixir
  defcustom_composition_pattern RetryComposition do
    @pattern_type :retry
    @max_retries 3

    def compose(intents, opts) do
      max_retries = Map.get(opts, :max_retries, @max_retries)
      compose_with_retry(intents, max_retries)
    end

    defp compose_with_retry(intents, retries_left) do
      case PacketFlow.Intent.Dynamic.compose_intents(intents, :sequential) do
        {:ok, results} ->
          {:ok, results}
        {:error, _reason} when retries_left > 0 ->
          compose_with_retry(intents, retries_left - 1)
        {:error, reason} ->
          {:error, reason}
      end
    end
  end
  """
  defmacro defcustom_composition_pattern(name, do: body) do
    quote do
      defmodule unquote(name) do
        @behaviour PacketFlow.Intent.Plugin.CompositionPattern

        # Composition pattern configuration
        @pattern_type :custom_composition
        @default_opts %{}

        unquote(body)

        # Default implementations
        def pattern_type do
          @pattern_type
        end

        def default_opts do
          @default_opts
        end

        def compose(intents, opts) do
          # Default composition logic
          PacketFlow.Intent.Dynamic.compose_intents(intents, :sequential, opts)
        end
      end
    end
  end
end

defmodule PacketFlow.Intent.Plugin.Behaviour do
  @moduledoc """
  Behaviour for intent plugins
  """

  @callback validate(any()) :: {:ok, any()} | {:error, any()}
  @callback transform(any()) :: {:ok, any()} | {:error, any()}
  @callback route(any(), list()) :: {:ok, any()} | {:error, any()}
  @callback compose(list(), any()) :: {:ok, any()} | {:error, any()}
  @callback plugin_type() :: atom()
  @callback priority() :: integer()
end

defmodule PacketFlow.Intent.Plugin.CustomType do
  @moduledoc """
  Behaviour for custom intent types
  """

  @callback intent_type() :: atom()
  @callback capabilities() :: list()
  @callback validate(any()) :: {:ok, any()} | {:error, any()}
  @callback transform(any()) :: {:ok, any()} | {:error, any()}
end

defmodule PacketFlow.Intent.Plugin.RoutingStrategy do
  @moduledoc """
  Behaviour for custom routing strategies
  """

  @callback strategy_type() :: atom()
  @callback targets() :: list()
  @callback route(any(), list()) :: {:ok, any()} | {:error, any()}
end

defmodule PacketFlow.Intent.Plugin.CompositionPattern do
  @moduledoc """
  Behaviour for custom composition patterns
  """

  @callback pattern_type() :: atom()
  @callback default_opts() :: map()
  @callback compose(list(), map()) :: {:ok, any()} | {:error, any()}
end

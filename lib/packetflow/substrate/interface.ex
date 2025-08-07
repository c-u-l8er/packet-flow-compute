defmodule PacketFlow.Substrate.Interface do
  @moduledoc """
  Standard interfaces for PacketFlow substrates

  This module defines the standard interfaces that all substrates must implement
  for proper communication, composition, and monitoring.
  """

  @doc """
  Substrate initialization interface
  """
  @callback init_substrate(config :: map()) :: {:ok, state :: map()} | {:error, reason :: any()}

  @doc """
  Substrate composition interface
  """
  @callback compose_with(other_substrate :: module(), config :: map()) ::
    {:ok, composed_module :: module()} | {:error, reason :: any()}

  @doc """
  Substrate communication interface
  """
  @callback send_message(message :: any(), target :: any()) ::
    {:ok, response :: any()} | {:error, reason :: any()}

  @doc """
  Substrate monitoring interface
  """
  @callback get_health_status() :: map()

  @doc """
  Substrate configuration interface
  """
  @callback update_config(config :: map()) :: :ok | {:error, reason :: any()}

  @doc """
  Substrate lifecycle interface
  """
  @callback start_substrate() :: :ok | {:error, reason :: any()}
  @callback stop_substrate() :: :ok | {:error, reason :: any()}
  @callback restart_substrate() :: :ok | {:error, reason :: any()}

  @doc """
  Substrate capability interface
  """
  @callback get_capabilities() :: [atom()]
  @callback has_capability(capability :: atom()) :: boolean()

  @doc """
  Substrate dependency interface
  """
  @callback get_dependencies() :: [module()]
  @callback add_dependency(dependency :: module()) :: :ok | {:error, reason :: any()}
  @callback remove_dependency(dependency :: module()) :: :ok | {:error, reason :: any()}

  @doc """
  Substrate metrics interface
  """
  @callback get_metrics() :: map()
  @callback record_metric(metric :: atom(), value :: any()) :: :ok

  @doc """
  Substrate event interface
  """
  @callback subscribe_to_events(pid :: pid()) :: :ok | {:error, reason :: any()}
  @callback unsubscribe_from_events(pid :: pid()) :: :ok | {:error, reason :: any()}
  @callback emit_event(event :: atom(), data :: any()) :: :ok

  @doc """
  Substrate validation interface
  """
  @callback validate_config(config :: map()) :: {:ok, validated_config :: map()} | {:error, reason :: any()}
  @callback validate_message(message :: any()) :: {:ok, validated_message :: any()} | {:error, reason :: any()}

  @doc """
  Substrate serialization interface
  """
  @callback serialize_state() :: binary()
  @callback deserialize_state(serialized :: binary()) :: {:ok, state :: map()} | {:error, reason :: any()}

  @doc """
  Substrate migration interface
  """
  @callback migrate_to(target_node :: atom()) :: :ok | {:error, reason :: any()}
  @callback accept_migration(migrating_substrate :: module(), state :: map()) :: :ok | {:error, reason :: any()}

  @doc """
  Substrate backup interface
  """
  @callback create_backup() :: {:ok, backup_data :: map()} | {:error, reason :: any()}
  @callback restore_from_backup(backup_data :: map()) :: :ok | {:error, reason :: any()}

  @doc """
  Substrate versioning interface
  """
  @callback get_version() :: String.t()
  @callback is_compatible_with(other_version :: String.t()) :: boolean()

  @doc """
  Substrate security interface
  """
  @callback authenticate(credentials :: map()) :: {:ok, permissions :: [atom()]} | {:error, reason :: any()}
  @callback authorize(permission :: atom(), resource :: any()) :: boolean()

  @doc """
  Substrate debugging interface
  """
  @callback get_debug_info() :: map()
  @callback set_debug_level(level :: atom()) :: :ok
  @callback get_logs() :: [String.t()]

  @doc """
  Substrate optimization interface
  """
  @callback optimize() :: {:ok, optimizations :: [map()]} | {:error, reason :: any()}
  @callback get_performance_stats() :: map()

  @doc """
  Substrate integration interface
  """
  @callback integrate_with(external_system :: atom(), config :: map()) ::
    {:ok, integration_id :: atom()} | {:error, reason :: any()}
  @callback disconnect_from(integration_id :: atom()) :: :ok | {:error, reason :: any()}

  @doc """
  Substrate discovery interface
  """
  @callback discover_peers() :: [map()]
  @callback register_with_registry(registry :: atom()) :: :ok | {:error, reason :: any()}
  @callback unregister_from_registry(registry :: atom()) :: :ok | {:error, reason :: any()}

  @doc """
  Substrate fault tolerance interface
  """
  @callback handle_failure(failure :: map()) :: :ok | {:error, reason :: any()}
  @callback get_failure_history() :: [map()]
  @callback clear_failure_history() :: :ok

  @doc """
  Substrate scaling interface
  """
  @callback scale_up(factor :: float()) :: :ok | {:error, reason :: any()}
  @callback scale_down(factor :: float()) :: :ok | {:error, reason :: any()}
  @callback get_scaling_recommendations() :: [map()]

  @doc """
  Substrate resource management interface
  """
  @callback get_resource_usage() :: map()
  @callback set_resource_limits(limits :: map()) :: :ok | {:error, reason :: any()}
  @callback get_resource_limits() :: map()

  @doc """
  Substrate time management interface
  """
  @callback get_time_constraints() :: [map()]
  @callback set_time_constraints(constraints :: [map()]) :: :ok | {:error, reason :: any()}
  @callback is_within_time_constraints() :: boolean()

  @doc """
  Substrate data flow interface
  """
  @callback get_input_ports() :: [map()]
  @callback get_output_ports() :: [map()]
  @callback connect_port(port_type :: :input | :output, port_id :: atom(), target :: any()) ::
    :ok | {:error, reason :: any()}
  @callback disconnect_port(port_type :: :input | :output, port_id :: atom()) ::
    :ok | {:error, reason :: any()}

  @doc """
  Substrate state management interface
  """
  @callback get_state() :: map()
  @callback set_state(state :: map()) :: :ok | {:error, reason :: any()}
  @callback update_state(updates :: map()) :: :ok | {:error, reason :: any()}
  @callback reset_state() :: :ok | {:error, reason :: any()}

  @doc """
  Substrate transaction interface
  """
  @callback begin_transaction() :: {:ok, transaction_id :: atom()} | {:error, reason :: any()}
  @callback commit_transaction(transaction_id :: atom()) :: :ok | {:error, reason :: any()}
  @callback rollback_transaction(transaction_id :: atom()) :: :ok | {:error, reason :: any()}

  @doc """
  Substrate notification interface
  """
  @callback subscribe_to_notifications(pid :: pid(), notification_types :: [atom()]) ::
    :ok | {:error, reason :: any()}
  @callback unsubscribe_from_notifications(pid :: pid()) :: :ok | {:error, reason :: any()}
  @callback send_notification(notification_type :: atom(), data :: any()) :: :ok

  @doc """
  Substrate validation helpers
  """
  defmacro __using__(_opts) do
    quote do
      @behaviour PacketFlow.Substrate.Interface

      # Default implementations for optional callbacks
      def init_substrate(config), do: {:ok, %{config: config}}
      def compose_with(_other, _config), do: {:error, :not_implemented}
      def send_message(_message, _target), do: {:error, :not_implemented}
      def get_health_status, do: %{status: :unknown}
      def update_config(_config), do: {:error, :not_implemented}
      def start_substrate, do: :ok
      def stop_substrate, do: :ok
      def restart_substrate, do: {:error, :not_implemented}
      def get_capabilities, do: []
      def has_capability(_capability), do: false
      def get_dependencies, do: []
      def add_dependency(_dependency), do: {:error, :not_implemented}
      def remove_dependency(_dependency), do: {:error, :not_implemented}
      def get_metrics, do: %{}
      def record_metric(_metric, _value), do: :ok
      def subscribe_to_events(_pid), do: {:error, :not_implemented}
      def unsubscribe_from_events(_pid), do: {:error, :not_implemented}
      def emit_event(_event, _data), do: :ok
      def validate_config(config), do: {:ok, config}
      def validate_message(message), do: {:ok, message}
      def serialize_state, do: :erlang.term_to_binary(%{})
      def deserialize_state(serialized), do: {:ok, :erlang.binary_to_term(serialized)}
      def migrate_to(_target), do: {:error, :not_implemented}
      def accept_migration(_migrating, _state), do: {:error, :not_implemented}
      def create_backup, do: {:ok, %{}}
      def restore_from_backup(_backup), do: {:error, :not_implemented}
      def get_version, do: "1.0.0"
      def is_compatible_with(_other), do: true
      def authenticate(_credentials), do: {:ok, []}
      def authorize(_permission, _resource), do: false
      def get_debug_info, do: %{}
      def set_debug_level(_level), do: :ok
      def get_logs, do: []
      def optimize, do: {:ok, []}
      def get_performance_stats, do: %{}
      def integrate_with(_system, _config), do: {:error, :not_implemented}
      def disconnect_from(_integration), do: {:error, :not_implemented}
      def discover_peers, do: []
      def register_with_registry(_registry), do: {:error, :not_implemented}
      def unregister_from_registry(_registry), do: {:error, :not_implemented}
      def handle_failure(_failure), do: :ok
      def get_failure_history, do: []
      def clear_failure_history, do: :ok
      def scale_up(_factor), do: {:error, :not_implemented}
      def scale_down(_factor), do: {:error, :not_implemented}
      def get_scaling_recommendations, do: []
      def get_resource_usage, do: %{}
      def set_resource_limits(_limits), do: {:error, :not_implemented}
      def get_resource_limits, do: %{}
      def get_time_constraints, do: []
      def set_time_constraints(_constraints), do: {:error, :not_implemented}
      def is_within_time_constraints, do: true
      def get_input_ports, do: []
      def get_output_ports, do: []
      def connect_port(_type, _port, _target), do: {:error, :not_implemented}
      def disconnect_port(_type, _port), do: {:error, :not_implemented}
      def get_state, do: %{}
      def set_state(_state), do: {:error, :not_implemented}
      def update_state(_updates), do: {:error, :not_implemented}
      def reset_state, do: {:error, :not_implemented}
      def begin_transaction, do: {:error, :not_implemented}
      def commit_transaction(_transaction), do: {:error, :not_implemented}
      def rollback_transaction(_transaction), do: {:error, :not_implemented}
      def subscribe_to_notifications(_pid, _types), do: {:error, :not_implemented}
      def unsubscribe_from_notifications(_pid), do: {:error, :not_implemented}
      def send_notification(_type, _data), do: :ok

      defoverridable [
        init_substrate: 1,
        compose_with: 2,
        send_message: 2,
        get_health_status: 0,
        update_config: 1,
        start_substrate: 0,
        stop_substrate: 0,
        restart_substrate: 0,
        get_capabilities: 0,
        has_capability: 1,
        get_dependencies: 0,
        add_dependency: 1,
        remove_dependency: 1,
        get_metrics: 0,
        record_metric: 2,
        subscribe_to_events: 1,
        unsubscribe_from_events: 1,
        emit_event: 2,
        validate_config: 1,
        validate_message: 1,
        serialize_state: 0,
        deserialize_state: 1,
        migrate_to: 1,
        accept_migration: 2,
        create_backup: 0,
        restore_from_backup: 1,
        get_version: 0,
        is_compatible_with: 1,
        authenticate: 1,
        authorize: 2,
        get_debug_info: 0,
        set_debug_level: 1,
        get_logs: 0,
        optimize: 0,
        get_performance_stats: 0,
        integrate_with: 2,
        disconnect_from: 1,
        discover_peers: 0,
        register_with_registry: 1,
        unregister_from_registry: 1,
        handle_failure: 1,
        get_failure_history: 0,
        clear_failure_history: 0,
        scale_up: 1,
        scale_down: 1,
        get_scaling_recommendations: 0,
        get_resource_usage: 0,
        set_resource_limits: 1,
        get_resource_limits: 0,
        get_time_constraints: 0,
        set_time_constraints: 1,
        is_within_time_constraints: 0,
        get_input_ports: 0,
        get_output_ports: 0,
        connect_port: 3,
        disconnect_port: 2,
        get_state: 0,
        set_state: 1,
        update_state: 1,
        reset_state: 0,
        begin_transaction: 0,
        commit_transaction: 1,
        rollback_transaction: 1,
        subscribe_to_notifications: 2,
        unsubscribe_from_notifications: 1,
        send_notification: 2
      ]
    end
  end
end

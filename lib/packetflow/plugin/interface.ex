defmodule PacketFlow.Plugin.Interface do
  @moduledoc """
  Standard interfaces for PacketFlow plugins

  This module defines the standard interfaces that plugins must implement
  to integrate with the PacketFlow system.
  """

  @doc """
  Base plugin interface that all plugins must implement
  """
  @callback init(map()) :: :ok | {:error, String.t()}
  @callback process(any(), map()) :: {:ok, any()} | {:error, String.t()}
  @callback version() :: String.t()
  @callback dependencies() :: [atom()]
  @callback default_config() :: map()
  @callback cleanup() :: :ok

  @doc """
  Capability plugin interface
  """
  @callback validate_capability(any(), map()) :: {:ok, boolean()} | {:error, String.t()}
  @callback compose_capabilities([any()], map()) :: {:ok, any()} | {:error, String.t()}
  @callback delegate_capability(any(), any(), map()) :: {:ok, any()} | {:error, String.t()}

  @doc """
  Intent plugin interface
  """
  @callback route_intent(any(), [any()], map()) :: {:ok, any()} | {:error, String.t()}
  @callback transform_intent(any(), map()) :: {:ok, any()} | {:error, String.t()}
  @callback validate_intent(any(), map()) :: {:ok, boolean()} | {:error, String.t()}

  @doc """
  Context plugin interface
  """
  @callback propagate_context(any(), map()) :: {:ok, any()} | {:error, String.t()}
  @callback compose_context([any()], map()) :: {:ok, any()} | {:error, String.t()}
  @callback validate_context(any(), map()) :: {:ok, boolean()} | {:error, String.t()}

  @doc """
  Reactor plugin interface
  """
  @callback process_reactor(any(), map()) :: {:ok, any()} | {:error, String.t()}
  @callback compose_reactors([any()], map()) :: {:ok, any()} | {:error, String.t()}
  @callback validate_reactor(any(), map()) :: {:ok, boolean()} | {:error, String.t()}

  @doc """
  Stream plugin interface
  """
  @callback process_stream(any(), map()) :: {:ok, any()} | {:error, String.t()}
  @callback transform_stream(any(), map()) :: {:ok, any()} | {:error, String.t()}
  @callback validate_stream(any(), map()) :: {:ok, boolean()} | {:error, String.t()}

  @doc """
  Temporal plugin interface
  """
  @callback process_temporal(any(), map()) :: {:ok, any()} | {:error, String.t()}
  @callback schedule_temporal(any(), map()) :: {:ok, any()} | {:error, String.t()}
  @callback validate_temporal(any(), map()) :: {:ok, boolean()} | {:error, String.t()}

  @doc """
  Web component plugin interface
  """
  @callback render_component(any(), map()) :: {:ok, any()} | {:error, String.t()}
  @callback validate_component(any(), map()) :: {:ok, boolean()} | {:error, String.t()}
  @callback transform_component(any(), map()) :: {:ok, any()} | {:error, String.t()}

  @doc """
  Test plugin interface
  """
  @callback run_test(any(), map()) :: {:ok, any()} | {:error, String.t()}
  @callback validate_test(any(), map()) :: {:ok, boolean()} | {:error, String.t()}
  @callback generate_test(any(), map()) :: {:ok, any()} | {:error, String.t()}

  @doc """
  Documentation plugin interface
  """
  @callback generate_docs(any(), map()) :: {:ok, any()} | {:error, String.t()}
  @callback validate_docs(any(), map()) :: {:ok, boolean()} | {:error, String.t()}
  @callback transform_docs(any(), map()) :: {:ok, any()} | {:error, String.t()}

  @doc """
  Macro to define a capability plugin
  """
  defmacro defcapability_plugin(name, do: body) do
    quote do
      defmodule unquote(name) do
        @behaviour PacketFlow.Plugin.Interface

        unquote(body)

        # Default implementations
        def init(_config), do: :ok
        def process(_data, _config), do: {:ok, nil}
        def version, do: "1.0.0"
        def dependencies, do: []
        def default_config, do: %{}
        def cleanup, do: :ok

        def validate_capability(_capability, _config), do: {:ok, true}
        def compose_capabilities(_capabilities, _config), do: {:ok, nil}
        def delegate_capability(_capability, _target, _config), do: {:ok, nil}
      end
    end
  end

  @doc """
  Macro to define an intent plugin
  """
  defmacro defintent_plugin(name, do: body) do
    quote do
      defmodule unquote(name) do
        @behaviour PacketFlow.Plugin.Interface

        unquote(body)

        # Default implementations
        def init(_config), do: :ok
        def process(_data, _config), do: {:ok, nil}
        def version, do: "1.0.0"
        def dependencies, do: []
        def default_config, do: %{}
        def cleanup, do: :ok

        def route_intent(_intent, _targets, _config), do: {:ok, nil}
        def transform_intent(_intent, _config), do: {:ok, nil}
        def validate_intent(_intent, _config), do: {:ok, true}
      end
    end
  end

  @doc """
  Macro to define a context plugin
  """
  defmacro defcontext_plugin(name, do: body) do
    quote do
      defmodule unquote(name) do
        @behaviour PacketFlow.Plugin.Interface

        unquote(body)

        # Default implementations
        def init(_config), do: :ok
        def process(_data, _config), do: {:ok, nil}
        def version, do: "1.0.0"
        def dependencies, do: []
        def default_config, do: %{}
        def cleanup, do: :ok

        def propagate_context(_context, _config), do: {:ok, nil}
        def compose_context(_contexts, _config), do: {:ok, nil}
        def validate_context(_context, _config), do: {:ok, true}
      end
    end
  end

  @doc """
  Macro to define a reactor plugin
  """
  defmacro defreactor_plugin(name, do: body) do
    quote do
      defmodule unquote(name) do
        @behaviour PacketFlow.Plugin.Interface

        unquote(body)

        # Default implementations
        def init(_config), do: :ok
        def process(_data, _config), do: {:ok, nil}
        def version, do: "1.0.0"
        def dependencies, do: []
        def default_config, do: %{}
        def cleanup, do: :ok

        def process_reactor(_reactor, _config), do: {:ok, nil}
        def compose_reactors(_reactors, _config), do: {:ok, nil}
        def validate_reactor(_reactor, _config), do: {:ok, true}
      end
    end
  end

  @doc """
  Macro to define a stream plugin
  """
  defmacro defstream_plugin(name, do: body) do
    quote do
      defmodule unquote(name) do
        @behaviour PacketFlow.Plugin.Interface

        unquote(body)

        # Default implementations
        def init(_config), do: :ok
        def process(_data, _config), do: {:ok, nil}
        def version, do: "1.0.0"
        def dependencies, do: []
        def default_config, do: %{}
        def cleanup, do: :ok

        def process_stream(_stream, _config), do: {:ok, nil}
        def transform_stream(_stream, _config), do: {:ok, nil}
        def validate_stream(_stream, _config), do: {:ok, true}
      end
    end
  end

  @doc """
  Macro to define a temporal plugin
  """
  defmacro deftemporal_plugin(name, do: body) do
    quote do
      defmodule unquote(name) do
        @behaviour PacketFlow.Plugin.Interface

        unquote(body)

        # Default implementations
        def init(_config), do: :ok
        def process(_data, _config), do: {:ok, nil}
        def version, do: "1.0.0"
        def dependencies, do: []
        def default_config, do: %{}
        def cleanup, do: :ok

        def process_temporal(_temporal, _config), do: {:ok, nil}
        def schedule_temporal(_temporal, _config), do: {:ok, nil}
        def validate_temporal(_temporal, _config), do: {:ok, true}
      end
    end
  end

  @doc """
  Macro to define a web component plugin
  """
  defmacro defweb_plugin(name, do: body) do
    quote do
      defmodule unquote(name) do
        @behaviour PacketFlow.Plugin.Interface

        unquote(body)

        # Default implementations
        def init(_config), do: :ok
        def process(_data, _config), do: {:ok, nil}
        def version, do: "1.0.0"
        def dependencies, do: []
        def default_config, do: %{}
        def cleanup, do: :ok

        def render_component(_component, _config), do: {:ok, nil}
        def validate_component(_component, _config), do: {:ok, true}
        def transform_component(_component, _config), do: {:ok, nil}
      end
    end
  end

  @doc """
  Macro to define a test plugin
  """
  defmacro deftest_plugin(name, do: body) do
    quote do
      defmodule unquote(name) do
        @behaviour PacketFlow.Plugin.Interface

        unquote(body)

        # Default implementations
        def init(_config), do: :ok
        def process(_data, _config), do: {:ok, nil}
        def version, do: "1.0.0"
        def dependencies, do: []
        def default_config, do: %{}
        def cleanup, do: :ok

        def run_test(_test, _config), do: {:ok, nil}
        def validate_test(_test, _config), do: {:ok, true}
        def generate_test(_spec, _config), do: {:ok, nil}
      end
    end
  end

  @doc """
  Macro to define a documentation plugin
  """
  defmacro defdocs_plugin(name, do: body) do
    quote do
      defmodule unquote(name) do
        @behaviour PacketFlow.Plugin.Interface

        unquote(body)

        # Default implementations
        def init(_config), do: :ok
        def process(_data, _config), do: {:ok, nil}
        def version, do: "1.0.0"
        def dependencies, do: []
        def default_config, do: %{}
        def cleanup, do: :ok

        def generate_docs(_spec, _config), do: {:ok, nil}
        def validate_docs(_docs, _config), do: {:ok, true}
        def transform_docs(_docs, _config), do: {:ok, nil}
      end
    end
  end
end

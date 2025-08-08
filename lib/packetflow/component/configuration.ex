defmodule PacketFlow.Component.Configuration do
  @moduledoc """
  Component configuration interfaces for dynamic configuration

  This module provides:
  - Dynamic configuration management
  - Configuration validation and schema definitions
  - Runtime configuration updates
  - Configuration templates and profiles
  - Configuration versioning and rollback
  - Environment-specific configurations
  """

  use GenServer

  @type config_key :: atom() | String.t() | [atom() | String.t()]
  @type config_value :: term()
  @type config_schema :: %{
    type: :string | :integer | :float | :boolean | :list | :map | :atom,
    required: boolean(),
    default: config_value(),
    validator: function() | nil,
    description: String.t()
  }

  @type component_config :: %{
    component_id: atom(),
    config: map(),
    schema: %{config_key() => config_schema()},
    version: String.t(),
    environment: atom(),
    last_updated: integer(),
    metadata: map()
  }

  @type config_template :: %{
    name: String.t(),
    description: String.t(),
    config: map(),
    schema: %{config_key() => config_schema()},
    environments: [atom()]
  }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    {:ok, %{
      component_configs: %{},
      config_schemas: %{},
      config_templates: %{},
      config_history: %{},
      watchers: %{},
      environments: [:dev, :test, :staging, :prod],
      current_environment: get_current_environment()
    }}
  end

  @doc """
  Register a component configuration with schema
  """
  @spec register_component_config(atom(), map(), map()) :: :ok | {:error, term()}
  def register_component_config(component_id, initial_config, schema) do
    GenServer.call(__MODULE__, {:register_component_config, component_id, initial_config, schema})
  end

  @doc """
  Unregister a component configuration
  """
  @spec unregister_component_config(atom()) :: :ok
  def unregister_component_config(component_id) do
    GenServer.call(__MODULE__, {:unregister_component_config, component_id})
  end

  @doc """
  Get configuration for a component
  """
  @spec get_config(atom()) :: map() | {:error, term()}
  def get_config(component_id) do
    GenServer.call(__MODULE__, {:get_config, component_id})
  end

  @doc """
  Get a specific configuration value
  """
  @spec get_config_value(atom(), config_key()) :: config_value() | {:error, term()}
  def get_config_value(component_id, key) do
    GenServer.call(__MODULE__, {:get_config_value, component_id, key})
  end

  @doc """
  Update configuration for a component
  """
  @spec update_config(atom(), map()) :: :ok | {:error, term()}
  def update_config(component_id, new_config) do
    GenServer.call(__MODULE__, {:update_config, component_id, new_config})
  end

  @doc """
  Update a specific configuration value
  """
  @spec update_config_value(atom(), config_key(), config_value()) :: :ok | {:error, term()}
  def update_config_value(component_id, key, value) do
    GenServer.call(__MODULE__, {:update_config_value, component_id, key, value})
  end

  @doc """
  Validate configuration against schema
  """
  @spec validate_config(atom(), map()) :: :ok | {:error, [String.t()]}
  def validate_config(component_id, config) do
    GenServer.call(__MODULE__, {:validate_config, component_id, config})
  end

  @doc """
  Get configuration schema for a component
  """
  @spec get_config_schema(atom()) :: map() | {:error, term()}
  def get_config_schema(component_id) do
    GenServer.call(__MODULE__, {:get_config_schema, component_id})
  end

  @doc """
  Update configuration schema for a component
  """
  @spec update_config_schema(atom(), map()) :: :ok | {:error, term()}
  def update_config_schema(component_id, schema) do
    GenServer.call(__MODULE__, {:update_config_schema, component_id, schema})
  end

  @doc """
  Create a configuration template
  """
  @spec create_config_template(String.t(), String.t(), map(), map(), [atom()]) :: :ok | {:error, term()}
  def create_config_template(name, description, config, schema, environments \\ [:dev, :test, :prod]) do
    GenServer.call(__MODULE__, {:create_config_template, name, description, config, schema, environments})
  end

  @doc """
  Apply a configuration template to a component
  """
  @spec apply_config_template(atom(), String.t()) :: :ok | {:error, term()}
  def apply_config_template(component_id, template_name) do
    GenServer.call(__MODULE__, {:apply_config_template, component_id, template_name})
  end

  @doc """
  Get configuration history for a component
  """
  @spec get_config_history(atom()) :: [component_config()] | {:error, term()}
  def get_config_history(component_id) do
    GenServer.call(__MODULE__, {:get_config_history, component_id})
  end

  @doc """
  Rollback to a previous configuration version
  """
  @spec rollback_config(atom(), String.t()) :: :ok | {:error, term()}
  def rollback_config(component_id, version) do
    GenServer.call(__MODULE__, {:rollback_config, component_id, version})
  end

  @doc """
  Watch configuration changes for a component
  """
  @spec watch_config(atom(), pid()) :: :ok
  def watch_config(component_id, watcher_pid) do
    GenServer.call(__MODULE__, {:watch_config, component_id, watcher_pid})
  end

  @doc """
  Unwatch configuration changes
  """
  @spec unwatch_config(atom(), pid()) :: :ok
  def unwatch_config(component_id, watcher_pid) do
    GenServer.call(__MODULE__, {:unwatch_config, component_id, watcher_pid})
  end

  @doc """
  Get all component configurations
  """
  @spec get_all_configs() :: %{atom() => component_config()}
  def get_all_configs() do
    GenServer.call(__MODULE__, :get_all_configs)
  end

  @doc """
  Export configuration to file
  """
  @spec export_config(atom(), String.t()) :: :ok | {:error, term()}
  def export_config(component_id, file_path) do
    GenServer.call(__MODULE__, {:export_config, component_id, file_path})
  end

  @doc """
  Import configuration from file
  """
  @spec import_config(atom(), String.t()) :: :ok | {:error, term()}
  def import_config(component_id, file_path) do
    GenServer.call(__MODULE__, {:import_config, component_id, file_path})
  end

  # GenServer callbacks

  def handle_call({:register_component_config, component_id, initial_config, schema}, _from, state) do
    case validate_config_against_schema(initial_config, schema) do
      :ok ->
        component_config = %{
          component_id: component_id,
          config: initial_config,
          schema: schema,
          version: generate_version(),
          environment: state.current_environment,
          last_updated: System.system_time(:millisecond),
          metadata: %{}
        }

        new_component_configs = Map.put(state.component_configs, component_id, component_config)
        new_config_schemas = Map.put(state.config_schemas, component_id, schema)

        # Initialize config history
        new_config_history = Map.put(state.config_history, component_id, [component_config])

        new_state = %{state |
          component_configs: new_component_configs,
          config_schemas: new_config_schemas,
          config_history: new_config_history
        }

        {:reply, :ok, new_state}

      {:error, errors} ->
        {:reply, {:error, {:validation_failed, errors}}, state}
    end
  end

  def handle_call({:unregister_component_config, component_id}, _from, state) do
    new_component_configs = Map.delete(state.component_configs, component_id)
    new_config_schemas = Map.delete(state.config_schemas, component_id)
    new_config_history = Map.delete(state.config_history, component_id)
    new_watchers = Map.delete(state.watchers, component_id)

    new_state = %{state |
      component_configs: new_component_configs,
      config_schemas: new_config_schemas,
      config_history: new_config_history,
      watchers: new_watchers
    }

    {:reply, :ok, new_state}
  end

  def handle_call({:get_config, component_id}, _from, state) do
    case Map.get(state.component_configs, component_id) do
      nil -> {:reply, {:error, :component_not_found}, state}
      component_config -> {:reply, component_config.config, state}
    end
  end

  def handle_call({:get_config_value, component_id, key}, _from, state) do
    case Map.get(state.component_configs, component_id) do
      nil ->
        {:reply, {:error, :component_not_found}, state}

      component_config ->
        value = get_nested_value(component_config.config, key)
        {:reply, value, state}
    end
  end

  def handle_call({:update_config, component_id, new_config}, _from, state) do
    case Map.get(state.component_configs, component_id) do
      nil ->
        {:reply, {:error, :component_not_found}, state}

      current_component_config ->
        schema = current_component_config.schema
        merged_config = Map.merge(current_component_config.config, new_config)

        case validate_config_against_schema(merged_config, schema) do
          :ok ->
            updated_component_config = %{current_component_config |
              config: merged_config,
              version: generate_version(),
              last_updated: System.system_time(:millisecond)
            }

            new_component_configs = Map.put(state.component_configs, component_id, updated_component_config)

            # Add to history
            new_config_history = Map.update(state.config_history, component_id, [updated_component_config], fn history ->
              [updated_component_config | Enum.take(history, 9)] # Keep last 10 versions
            end)

            new_state = %{state |
              component_configs: new_component_configs,
              config_history: new_config_history
            }

            # Notify watchers
            notify_config_watchers(component_id, {:config_updated, updated_component_config}, state.watchers)

            {:reply, :ok, new_state}

          {:error, errors} ->
            {:reply, {:error, {:validation_failed, errors}}, state}
        end
    end
  end

  def handle_call({:update_config_value, component_id, key, value}, _from, state) do
    case Map.get(state.component_configs, component_id) do
      nil ->
        {:reply, {:error, :component_not_found}, state}

      current_component_config ->
        updated_config = set_nested_value(current_component_config.config, key, value)

        case validate_config_against_schema(updated_config, current_component_config.schema) do
          :ok ->
            updated_component_config = %{current_component_config |
              config: updated_config,
              version: generate_version(),
              last_updated: System.system_time(:millisecond)
            }

            new_component_configs = Map.put(state.component_configs, component_id, updated_component_config)

            # Add to history
            new_config_history = Map.update(state.config_history, component_id, [updated_component_config], fn history ->
              [updated_component_config | Enum.take(history, 9)]
            end)

            new_state = %{state |
              component_configs: new_component_configs,
              config_history: new_config_history
            }

            # Notify watchers
            notify_config_watchers(component_id, {:config_value_updated, key, value}, state.watchers)

            {:reply, :ok, new_state}

          {:error, errors} ->
            {:reply, {:error, {:validation_failed, errors}}, state}
        end
    end
  end

  def handle_call({:validate_config, component_id, config}, _from, state) do
    case Map.get(state.config_schemas, component_id) do
      nil -> {:reply, {:error, :schema_not_found}, state}
      schema ->
        result = validate_config_against_schema(config, schema)
        {:reply, result, state}
    end
  end

  def handle_call({:get_config_schema, component_id}, _from, state) do
    case Map.get(state.config_schemas, component_id) do
      nil -> {:reply, {:error, :schema_not_found}, state}
      schema -> {:reply, schema, state}
    end
  end

  def handle_call({:update_config_schema, component_id, schema}, _from, state) do
    case Map.get(state.component_configs, component_id) do
      nil ->
        {:reply, {:error, :component_not_found}, state}

      component_config ->
        # Validate current config against new schema
        case validate_config_against_schema(component_config.config, schema) do
          :ok ->
            new_config_schemas = Map.put(state.config_schemas, component_id, schema)

            updated_component_config = %{component_config | schema: schema}
            new_component_configs = Map.put(state.component_configs, component_id, updated_component_config)

            new_state = %{state |
              config_schemas: new_config_schemas,
              component_configs: new_component_configs
            }

            {:reply, :ok, new_state}

          {:error, errors} ->
            {:reply, {:error, {:current_config_invalid, errors}}, state}
        end
    end
  end

  def handle_call({:create_config_template, name, description, config, schema, environments}, _from, state) do
    template = %{
      name: name,
      description: description,
      config: config,
      schema: schema,
      environments: environments
    }

    case validate_config_against_schema(config, schema) do
      :ok ->
        new_config_templates = Map.put(state.config_templates, name, template)
        new_state = %{state | config_templates: new_config_templates}
        {:reply, :ok, new_state}

      {:error, errors} ->
        {:reply, {:error, {:template_validation_failed, errors}}, state}
    end
  end

  def handle_call({:apply_config_template, component_id, template_name}, _from, state) do
    case Map.get(state.config_templates, template_name) do
      nil ->
        {:reply, {:error, :template_not_found}, state}

      template ->
        if state.current_environment in template.environments do
          # Apply template configuration
          case Map.get(state.component_configs, component_id) do
            nil ->
              {:reply, {:error, :component_not_found}, state}

            current_component_config ->
              merged_config = Map.merge(template.config, current_component_config.config)

              updated_component_config = %{current_component_config |
                config: merged_config,
                schema: Map.merge(template.schema, current_component_config.schema),
                version: generate_version(),
                last_updated: System.system_time(:millisecond)
              }

              new_component_configs = Map.put(state.component_configs, component_id, updated_component_config)
              new_config_schemas = Map.put(state.config_schemas, component_id, updated_component_config.schema)

              new_state = %{state |
                component_configs: new_component_configs,
                config_schemas: new_config_schemas
              }

              {:reply, :ok, new_state}
          end
        else
          {:reply, {:error, {:template_not_for_environment, state.current_environment}}, state}
        end
    end
  end

  def handle_call({:get_config_history, component_id}, _from, state) do
    case Map.get(state.config_history, component_id) do
      nil -> {:reply, {:error, :component_not_found}, state}
      history -> {:reply, history, state}
    end
  end

  def handle_call({:rollback_config, component_id, version}, _from, state) do
    case Map.get(state.config_history, component_id) do
      nil ->
        {:reply, {:error, :component_not_found}, state}

      history ->
        case Enum.find(history, fn config -> config.version == version end) do
          nil ->
            {:reply, {:error, :version_not_found}, state}

          target_config ->
            rollback_config = %{target_config |
              last_updated: System.system_time(:millisecond)
            }

            new_component_configs = Map.put(state.component_configs, component_id, rollback_config)

            # Add rollback to history
            new_config_history = Map.update(state.config_history, component_id, [rollback_config], fn hist ->
              [rollback_config | Enum.take(hist, 9)]
            end)

            new_state = %{state |
              component_configs: new_component_configs,
              config_history: new_config_history
            }

            # Notify watchers
            notify_config_watchers(component_id, {:config_rolled_back, rollback_config}, state.watchers)

            {:reply, :ok, new_state}
        end
    end
  end

  def handle_call({:watch_config, component_id, watcher_pid}, _from, state) do
    watchers = Map.update(state.watchers, component_id, [watcher_pid], fn current_watchers ->
      if watcher_pid in current_watchers, do: current_watchers, else: [watcher_pid | current_watchers]
    end)

    new_state = %{state | watchers: watchers}
    {:reply, :ok, new_state}
  end

  def handle_call({:unwatch_config, component_id, watcher_pid}, _from, state) do
    watchers = Map.update(state.watchers, component_id, [], fn current_watchers ->
      List.delete(current_watchers, watcher_pid)
    end)

    new_state = %{state | watchers: watchers}
    {:reply, :ok, new_state}
  end

  def handle_call(:get_all_configs, _from, state) do
    {:reply, state.component_configs, state}
  end

  def handle_call({:export_config, component_id, file_path}, _from, state) do
    case Map.get(state.component_configs, component_id) do
      nil ->
        {:reply, {:error, :component_not_found}, state}

      component_config ->
        case export_config_to_file(component_config, file_path) do
          :ok -> {:reply, :ok, state}
          {:error, reason} -> {:reply, {:error, reason}, state}
        end
    end
  end

  def handle_call({:import_config, component_id, file_path}, _from, state) do
    case import_config_from_file(file_path) do
      {:ok, imported_config} ->
        case Map.get(state.config_schemas, component_id) do
          nil ->
            {:reply, {:error, :schema_not_found}, state}

          schema ->
            case validate_config_against_schema(imported_config, schema) do
              :ok ->
                current_config = Map.get(state.component_configs, component_id)

                updated_component_config = %{current_config |
                  config: imported_config,
                  version: generate_version(),
                  last_updated: System.system_time(:millisecond)
                }

                new_component_configs = Map.put(state.component_configs, component_id, updated_component_config)
                new_state = %{state | component_configs: new_component_configs}

                {:reply, :ok, new_state}

              {:error, errors} ->
                {:reply, {:error, {:validation_failed, errors}}, state}
            end
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  # Private functions

  defp get_current_environment() do
    case System.get_env("MIX_ENV") do
      nil -> :dev
      env -> String.to_atom(env)
    end
  end

  defp generate_version() do
    timestamp = System.system_time(:microsecond)
    random = :rand.uniform(1000)
    "v#{timestamp}_#{random}"
  end

  defp validate_config_against_schema(config, schema) do
    errors = Enum.reduce(schema, [], fn {key, schema_def}, acc ->
      case validate_field(config, key, schema_def) do
        :ok -> acc
        {:error, error} -> [error | acc]
      end
    end)

    if Enum.empty?(errors) do
      :ok
    else
      {:error, Enum.reverse(errors)}
    end
  end

  defp validate_field(config, key, schema_def) do
    value = get_nested_value(config, key)

    cond do
      is_nil(value) and schema_def.required ->
        {:error, "Required field '#{inspect(key)}' is missing"}

      is_nil(value) and not schema_def.required ->
        :ok

      true ->
        validate_field_type_and_value(key, value, schema_def)
    end
  end

  defp validate_field_type_and_value(key, value, schema_def) do
    validator = Map.get(schema_def, :validator)
    with :ok <- validate_field_type(key, value, schema_def.type),
         :ok <- validate_field_with_custom_validator(key, value, validator) do
      :ok
    else
      {:error, error} -> {:error, error}
    end
  end

  defp validate_field_type(key, value, expected_type) do
    valid = case expected_type do
      :string -> is_binary(value)
      :integer -> is_integer(value)
      :float -> is_float(value) or is_integer(value)
      :boolean -> is_boolean(value)
      :list -> is_list(value)
      :map -> is_map(value)
      :atom -> is_atom(value)
      _ -> true
    end

    if valid do
      :ok
    else
      {:error, "Field '#{inspect(key)}' expected type #{expected_type}, got #{inspect(value)}"}
    end
  end

  defp validate_field_with_custom_validator(_key, _value, nil), do: :ok
  defp validate_field_with_custom_validator(key, value, validator) when is_function(validator, 1) do
    case validator.(value) do
      true -> :ok
      false -> {:error, "Field '#{inspect(key)}' failed custom validation"}
      {:error, reason} -> {:error, "Field '#{inspect(key)}': #{reason}"}
      _ -> {:error, "Field '#{inspect(key)}' custom validator returned invalid result"}
    end
  end

  defp get_nested_value(config, key) when is_atom(key) or is_binary(key) do
    Map.get(config, key)
  end
  defp get_nested_value(config, keys) when is_list(keys) do
    case keys do
      [] -> nil  # Empty key list should return nil
      _ ->
        Enum.reduce(keys, config, fn key, acc ->
          if is_map(acc), do: Map.get(acc, key), else: nil
        end)
    end
  end
  defp get_nested_value(_config, _invalid_key) do
    nil
  end

  defp set_nested_value(config, key, value) when is_atom(key) or is_binary(key) do
    Map.put(config, key, value)
  end
  defp set_nested_value(config, [key], value) do
    Map.put(config, key, value)
  end
  defp set_nested_value(config, [key | rest], value) do
    nested_config = Map.get(config, key, %{})
    updated_nested = set_nested_value(nested_config, rest, value)
    Map.put(config, key, updated_nested)
  end

  defp notify_config_watchers(component_id, event, watchers) do
    case Map.get(watchers, component_id, []) do
      [] -> :ok
      watcher_list ->
        Enum.each(watcher_list, fn watcher_pid ->
          send(watcher_pid, {:config_event, component_id, event})
        end)
    end
  end

  defp export_config_to_file(component_config, file_path) do
    try do
      config_data = %{
        component_id: component_config.component_id,
        config: component_config.config,
        schema: component_config.schema,
        version: component_config.version,
        environment: component_config.environment,
        exported_at: System.system_time(:millisecond)
      }

      json_data = Jason.encode!(config_data, pretty: true)
      File.write(file_path, json_data)
    rescue
      error -> {:error, error}
    end
  end

  defp import_config_from_file(file_path) do
    try do
      case File.read(file_path) do
        {:ok, content} ->
          case Jason.decode(content, keys: :atoms) do
            {:ok, data} -> {:ok, data.config}
            {:error, reason} -> {:error, {:json_decode_error, reason}}
          end

        {:error, reason} ->
          {:error, {:file_read_error, reason}}
      end
    rescue
      error -> {:error, error}
    end
  end
end

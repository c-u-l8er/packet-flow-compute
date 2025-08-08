defmodule PacketFlow.Component.ConfigurationTest do
  use ExUnit.Case, async: false  # Not async due to shared GenServer state

  alias PacketFlow.Component.Configuration

  setup do
    # Start the configuration service
    start_supervised!({Configuration, []})
    :ok
  end

  describe "component registration" do
    test "register_component_config with valid config and schema" do
      config = %{
        setting1: "value1",
        setting2: 42,
        setting3: true
      }

      schema = %{
        setting1: %{type: :string, required: true, default: "default", description: "String setting"},
        setting2: %{type: :integer, required: false, default: 0, description: "Integer setting"},
        setting3: %{type: :boolean, required: false, default: false, description: "Boolean setting"}
      }

      assert :ok = Configuration.register_component_config(:test_component, config, schema)
    end

    test "register_component_config fails with invalid config" do
      config = %{
        setting1: 123  # Should be string according to schema
      }

      schema = %{
        setting1: %{type: :string, required: true, default: "default", description: "String setting"}
      }

      assert {:error, {:validation_failed, errors}} =
        Configuration.register_component_config(:invalid_component, config, schema)

      assert is_list(errors)
      assert length(errors) > 0
    end

    test "register_component_config with missing required fields" do
      config = %{
        # Missing required_field
        optional_field: "value"
      }

      schema = %{
        required_field: %{type: :string, required: true, description: "Required field"},
        optional_field: %{type: :string, required: false, description: "Optional field"}
      }

      assert {:error, {:validation_failed, errors}} =
        Configuration.register_component_config(:missing_required, config, schema)

      assert Enum.any?(errors, fn error ->
        String.contains?(error, "required_field") and String.contains?(error, "missing")
      end)
    end

    test "unregister_component_config removes component" do
      config = %{setting: "value"}
      schema = %{setting: %{type: :string, required: false, description: "Test setting"}}

      :ok = Configuration.register_component_config(:temp_component, config, schema)
      assert Configuration.get_config(:temp_component) == config

      :ok = Configuration.unregister_component_config(:temp_component)
      assert {:error, :component_not_found} = Configuration.get_config(:temp_component)
    end
  end

  describe "configuration retrieval" do
    setup do
      config = %{
        database_url: "postgres://localhost/test",
        port: 4000,
        debug: true,
        features: %{
          feature_a: true,
          feature_b: false
        }
      }

      schema = %{
        database_url: %{type: :string, required: true, description: "Database URL"},
        port: %{type: :integer, required: true, description: "Server port"},
        debug: %{type: :boolean, required: false, default: false, description: "Debug mode"},
        features: %{type: :map, required: false, description: "Feature flags"}
      }

      :ok = Configuration.register_component_config(:test_app, config, schema)

      %{config: config, schema: schema}
    end

    test "get_config returns full configuration", %{config: config} do
      assert Configuration.get_config(:test_app) == config
    end

    test "get_config returns error for non-existent component" do
      assert {:error, :component_not_found} = Configuration.get_config(:non_existent)
    end

    test "get_config_value returns specific configuration value" do
      assert Configuration.get_config_value(:test_app, :database_url) == "postgres://localhost/test"
      assert Configuration.get_config_value(:test_app, :port) == 4000
      assert Configuration.get_config_value(:test_app, :debug) == true
    end

    test "get_config_value with nested keys" do
      assert Configuration.get_config_value(:test_app, [:features, :feature_a]) == true
      assert Configuration.get_config_value(:test_app, [:features, :feature_b]) == false
    end

    test "get_config_value returns nil for non-existent key" do
      assert Configuration.get_config_value(:test_app, :non_existent) == nil
    end

    test "get_config_value returns error for non-existent component" do
      assert {:error, :component_not_found} =
        Configuration.get_config_value(:non_existent, :any_key)
    end
  end

  describe "configuration updates" do
    setup do
      config = %{setting1: "original", setting2: 100}
      schema = %{
        setting1: %{type: :string, required: true, description: "String setting"},
        setting2: %{type: :integer, required: true, description: "Integer setting"},
        setting3: %{type: :boolean, required: false, default: false, description: "Boolean setting"}
      }

      :ok = Configuration.register_component_config(:update_test, config, schema)
      %{original_config: config, schema: schema}
    end

    test "update_config merges new configuration" do
      new_config = %{setting2: 200, setting3: true}

      assert :ok = Configuration.update_config(:update_test, new_config)

      updated_config = Configuration.get_config(:update_test)
      assert updated_config.setting1 == "original"  # unchanged
      assert updated_config.setting2 == 200         # updated
      assert updated_config.setting3 == true        # new
    end

    test "update_config validates against schema" do
      invalid_config = %{setting1: 123}  # Should be string

      assert {:error, {:validation_failed, errors}} =
        Configuration.update_config(:update_test, invalid_config)

      assert is_list(errors)
    end

    test "update_config returns error for non-existent component" do
      assert {:error, :component_not_found} =
        Configuration.update_config(:non_existent, %{})
    end

    test "update_config_value updates single value" do
      assert :ok = Configuration.update_config_value(:update_test, :setting2, 300)

      updated_value = Configuration.get_config_value(:update_test, :setting2)
      assert updated_value == 300
    end

    test "update_config_value with nested keys" do
      # First add a nested structure
      :ok = Configuration.update_config(:update_test, %{nested: %{key: "original"}})

      # Then update the nested value
      assert :ok = Configuration.update_config_value(:update_test, [:nested, :key], "updated")

      updated_value = Configuration.get_config_value(:update_test, [:nested, :key])
      assert updated_value == "updated"
    end

    test "update_config_value validates single value against schema" do
      assert {:error, {:validation_failed, _errors}} =
        Configuration.update_config_value(:update_test, :setting1, 123)  # Should be string
    end
  end

  describe "schema management" do
    setup do
      config = %{setting: "value"}
      schema = %{setting: %{type: :string, required: true, description: "Test setting"}}

      :ok = Configuration.register_component_config(:schema_test, config, schema)
      %{schema: schema}
    end

    test "get_config_schema returns component schema", %{schema: schema} do
      assert Configuration.get_config_schema(:schema_test) == schema
    end

    test "get_config_schema returns error for non-existent component" do
      assert {:error, :schema_not_found} = Configuration.get_config_schema(:non_existent)
    end

    test "update_config_schema updates schema and validates current config" do
      new_schema = %{
        setting: %{type: :string, required: true, description: "Updated setting"},
        new_setting: %{type: :integer, required: false, default: 0, description: "New setting"}
      }

      assert :ok = Configuration.update_config_schema(:schema_test, new_schema)

      updated_schema = Configuration.get_config_schema(:schema_test)
      assert Map.has_key?(updated_schema, :new_setting)
    end

    test "update_config_schema fails if current config is invalid against new schema" do
      # Current config has string value, new schema requires integer
      invalid_schema = %{
        setting: %{type: :integer, required: true, description: "Now requires integer"}
      }

      assert {:error, {:current_config_invalid, _errors}} =
        Configuration.update_config_schema(:schema_test, invalid_schema)
    end
  end

  describe "configuration validation" do
    setup do
      schema = %{
        string_field: %{type: :string, required: true, description: "String field"},
        integer_field: %{type: :integer, required: false, default: 0, description: "Integer field"},
        float_field: %{type: :float, required: false, description: "Float field"},
        boolean_field: %{type: :boolean, required: false, description: "Boolean field"},
        list_field: %{type: :list, required: false, description: "List field"},
        map_field: %{type: :map, required: false, description: "Map field"},
        atom_field: %{type: :atom, required: false, description: "Atom field"},
        custom_field: %{
          type: :string,
          required: false,
          validator: fn value -> String.length(value) > 5 end,
          description: "Custom validated field"
        }
      }

      :ok = Configuration.register_component_config(:validation_test, %{string_field: "test"}, schema)
      %{schema: schema}
    end

    test "validate_config accepts valid configuration", %{schema: _schema} do
      valid_config = %{
        string_field: "valid string",
        integer_field: 42,
        float_field: 3.14,
        boolean_field: true,
        list_field: [1, 2, 3],
        map_field: %{key: "value"},
        atom_field: :atom_value,
        custom_field: "long enough string"
      }

      assert :ok = Configuration.validate_config(:validation_test, valid_config)
    end

    test "validate_config rejects invalid types" do
      invalid_configs = [
        %{string_field: 123},           # Should be string
        %{integer_field: "not int"},    # Should be integer
        %{boolean_field: "not bool"},   # Should be boolean
        %{list_field: "not list"},      # Should be list
        %{map_field: "not map"},        # Should be map
        %{atom_field: "not atom"}       # Should be atom
      ]

      for invalid_config <- invalid_configs do
        config = Map.merge(%{string_field: "required"}, invalid_config)
        assert {:error, errors} = Configuration.validate_config(:validation_test, config)
        assert is_list(errors)
        assert length(errors) > 0
      end
    end

    test "validate_config rejects missing required fields" do
      config = %{} # Missing required string_field

      assert {:error, errors} = Configuration.validate_config(:validation_test, config)
      assert Enum.any?(errors, fn error ->
        String.contains?(error, "string_field") and String.contains?(error, "missing")
      end)
    end

    test "validate_config runs custom validators" do
      # Valid custom field (length > 5)
      valid_config = %{string_field: "test", custom_field: "long enough"}
      assert :ok = Configuration.validate_config(:validation_test, valid_config)

      # Invalid custom field (length <= 5)
      invalid_config = %{string_field: "test", custom_field: "short"}
      assert {:error, _errors} = Configuration.validate_config(:validation_test, invalid_config)
    end

    test "validate_config returns error for non-existent component" do
      assert {:error, :schema_not_found} =
        Configuration.validate_config(:non_existent, %{})
    end
  end

  describe "configuration templates" do
    test "create_config_template creates reusable template" do
      template_config = %{
        database_url: "postgres://localhost/template_db",
        port: 5000,
        debug: false
      }

      template_schema = %{
        database_url: %{type: :string, required: true, description: "Database URL"},
        port: %{type: :integer, required: true, description: "Server port"},
        debug: %{type: :boolean, required: false, default: false, description: "Debug mode"}
      }

      assert :ok = Configuration.create_config_template(
        "web_app_template",
        "Template for web applications",
        template_config,
        template_schema,
        [:dev, :test, :prod]
      )
    end

    test "create_config_template validates template config against schema" do
      invalid_config = %{port: "not an integer"}
      schema = %{port: %{type: :integer, required: true, description: "Port"}}

      assert {:error, {:template_validation_failed, _errors}} =
        Configuration.create_config_template("invalid_template", "Invalid", invalid_config, schema)
    end

    test "apply_config_template applies template to component" do
      # Create template
      template_config = %{template_setting: "from_template"}
      template_schema = %{template_setting: %{type: :string, required: false, description: "Template setting"}}

      :ok = Configuration.create_config_template(
        "test_template", "Test template", template_config, template_schema, [:dev, :test, :prod]
      )

      # Register component
      component_config = %{component_setting: "from_component"}
      component_schema = %{component_setting: %{type: :string, required: false, description: "Component setting"}}

      :ok = Configuration.register_component_config(:template_test, component_config, component_schema)

      # Apply template
      assert :ok = Configuration.apply_config_template(:template_test, "test_template")

      # Check merged configuration
      merged_config = Configuration.get_config(:template_test)
      assert merged_config.template_setting == "from_template"
      assert merged_config.component_setting == "from_component"
    end

    test "apply_config_template fails for wrong environment" do
      # Create template for specific environments
      :ok = Configuration.create_config_template(
        "prod_only_template", "Production only", %{}, %{}, [:prod]
      )

      # Register component
      :ok = Configuration.register_component_config(:env_test, %{}, %{})

      # Should fail in dev environment
      assert {:error, {:template_not_for_environment, _env}} =
        Configuration.apply_config_template(:env_test, "prod_only_template")
    end

    test "apply_config_template fails for non-existent template" do
      :ok = Configuration.register_component_config(:template_test, %{}, %{})

      assert {:error, :template_not_found} =
        Configuration.apply_config_template(:template_test, "non_existent_template")
    end
  end

  describe "configuration history and versioning" do
    setup do
      config = %{version_setting: "v1"}
      schema = %{version_setting: %{type: :string, required: true, description: "Version setting"}}

      :ok = Configuration.register_component_config(:version_test, config, schema)
      :ok
    end

    test "get_config_history returns configuration history" do
      # Make some configuration updates
      :ok = Configuration.update_config(:version_test, %{version_setting: "v2"})
      :ok = Configuration.update_config(:version_test, %{version_setting: "v3"})

      history = Configuration.get_config_history(:version_test)
      assert is_list(history)
      assert length(history) >= 3  # Initial + 2 updates

      # History should be ordered with most recent first
      [latest | _rest] = history
      assert latest.config.version_setting == "v3"
    end

    test "get_config_history returns error for non-existent component" do
      assert {:error, :component_not_found} =
        Configuration.get_config_history(:non_existent)
    end

    test "rollback_config restores previous configuration version" do
      # Make updates to create history
      :ok = Configuration.update_config(:version_test, %{version_setting: "v2"})
      :ok = Configuration.update_config(:version_test, %{version_setting: "v3"})

      # Get the version to rollback to
      history = Configuration.get_config_history(:version_test)
      v2_version = Enum.find(history, fn config -> config.config.version_setting == "v2" end)

      # Rollback to v2
      assert :ok = Configuration.rollback_config(:version_test, v2_version.version)

      # Check that configuration was rolled back
      current_config = Configuration.get_config(:version_test)
      assert current_config.version_setting == "v2"
    end

    test "rollback_config returns error for non-existent version" do
      assert {:error, :version_not_found} =
        Configuration.rollback_config(:version_test, "non_existent_version")
    end
  end

  describe "configuration watching" do
    setup do
      :ok = Configuration.register_component_config(:watch_test, %{setting: "initial"},
        %{setting: %{type: :string, required: true, description: "Watch setting"}})
      :ok
    end

    test "watch_config and unwatch_config manage watchers" do
      watcher_pid = self()

      assert :ok = Configuration.watch_config(:watch_test, watcher_pid)
      assert :ok = Configuration.unwatch_config(:watch_test, watcher_pid)
    end

    test "watchers receive configuration change events" do
      watcher_pid = self()
      :ok = Configuration.watch_config(:watch_test, watcher_pid)

      # Update configuration
      :ok = Configuration.update_config(:watch_test, %{setting: "updated"})

      # Check for configuration event
      receive do
        {:config_event, component_id, event} ->
          assert component_id == :watch_test
          assert elem(event, 0) == :config_updated
      after
        1000 ->
          flunk("Expected to receive config event")
      end
    end

    test "watchers receive config value update events" do
      watcher_pid = self()
      :ok = Configuration.watch_config(:watch_test, watcher_pid)

      # Update single value
      :ok = Configuration.update_config_value(:watch_test, :setting, "single_update")

      # Check for configuration event
      receive do
        {:config_event, component_id, event} ->
          assert component_id == :watch_test
          assert elem(event, 0) == :config_value_updated
      after
        1000 ->
          flunk("Expected to receive config value event")
      end
    end
  end

  describe "configuration import/export" do
    setup do
      config = %{export_setting: "exportable", number: 42}
      schema = %{
        export_setting: %{type: :string, required: true, description: "Exportable setting"},
        number: %{type: :integer, required: true, description: "Number setting"}
      }

      :ok = Configuration.register_component_config(:export_test, config, schema)
      %{config: config}
    end

    test "export_config creates configuration file", %{config: config} do
      file_path = "/tmp/test_config_export.json"

      # Clean up any existing file
      File.rm(file_path)

      assert :ok = Configuration.export_config(:export_test, file_path)
      assert File.exists?(file_path)

      # Verify file contents
      {:ok, content} = File.read(file_path)
      {:ok, exported_data} = Jason.decode(content, keys: :atoms)

      assert exported_data.component_id == "export_test"
      assert exported_data.config == config
      assert is_map(exported_data.schema)
      assert is_binary(exported_data.version)
      assert is_integer(exported_data.exported_at)

      # Cleanup
      File.rm(file_path)
    end

    test "export_config returns error for non-existent component" do
      assert {:error, :component_not_found} =
        Configuration.export_config(:non_existent, "/tmp/test.json")
    end

    test "import_config loads configuration from file" do
      # First export a configuration
      file_path = "/tmp/test_config_import.json"
      :ok = Configuration.export_config(:export_test, file_path)

      # Register a new component to import into
      :ok = Configuration.register_component_config(:import_test, %{},
        %{
          export_setting: %{type: :string, required: false, description: "Imported setting"},
          number: %{type: :integer, required: false, description: "Imported number"}
        })

      # Import the configuration
      assert :ok = Configuration.import_config(:import_test, file_path)

      # Verify imported configuration
      imported_config = Configuration.get_config(:import_test)
      assert imported_config.export_setting == "exportable"
      assert imported_config.number == 42

      # Cleanup
      File.rm(file_path)
    end

    test "import_config validates imported configuration against schema" do
      # Create a config file with invalid data
      file_path = "/tmp/test_invalid_import.json"
      invalid_data = %{config: %{export_setting: 123}}  # Should be string

      File.write!(file_path, Jason.encode!(invalid_data))

      # Register component with schema
      :ok = Configuration.register_component_config(:invalid_import_test, %{export_setting: "default"},
        %{export_setting: %{type: :string, required: true, description: "String setting"}})

      # Import should fail validation
      assert {:error, {:validation_failed, _errors}} =
        Configuration.import_config(:invalid_import_test, file_path)

      # Cleanup
      File.rm(file_path)
    end
  end

  describe "get_all_configs" do
    test "returns all registered component configurations" do
      # Register a few components
      :ok = Configuration.register_component_config(:comp1, %{setting: "value1"}, %{})
      :ok = Configuration.register_component_config(:comp2, %{setting: "value2"}, %{})

      all_configs = Configuration.get_all_configs()

      assert is_map(all_configs)
      assert Map.has_key?(all_configs, :comp1)
      assert Map.has_key?(all_configs, :comp2)

      assert all_configs[:comp1].config.setting == "value1"
      assert all_configs[:comp2].config.setting == "value2"
    end
  end

  describe "error handling and edge cases" do
    test "handles concurrent configuration updates" do
      :ok = Configuration.register_component_config(:concurrent_test, %{counter: 0},
        %{counter: %{type: :integer, required: true, description: "Counter"}})

      # Run multiple concurrent updates
      tasks = for i <- 1..10 do
        Task.async(fn ->
          Configuration.update_config_value(:concurrent_test, :counter, i)
        end)
      end

      # Wait for all tasks to complete
      results = Enum.map(tasks, &Task.await/1)

      # All updates should succeed
      assert Enum.all?(results, &(&1 == :ok))
    end

    test "handles invalid configuration keys gracefully" do
      :ok = Configuration.register_component_config(:edge_case_test, %{}, %{})

      # Try various invalid key types
      invalid_keys = [nil, "", [], %{}, {:complex, :tuple}]

      for invalid_key <- invalid_keys do
        result = Configuration.get_config_value(:edge_case_test, invalid_key)
        # Should return nil or handle gracefully, not crash
        case result do
          nil -> assert true
          {:error, _} -> assert true
          _ -> flunk("Unexpected result for key #{inspect(invalid_key)}: #{inspect(result)}")
        end
      end
    end
  end
end

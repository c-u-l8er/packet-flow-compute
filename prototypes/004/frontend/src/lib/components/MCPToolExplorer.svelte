<script>
  import { onMount } from 'svelte';
  import { authStore } from '$lib/stores/auth';

  let mcpTools = [];
  let selectedTool = null;
  let toolParameters = {};
  let executionResult = null;
  let loading = false;
  let error = null;

  // Load MCP tools on component mount
  onMount(async () => {
    await loadMCPTools();
  });

  async function loadMCPTools() {
    try {
      loading = true;
      error = null;

      const response = await fetch('/api/mcp/tools', {
        headers: {
          'Authorization': `Bearer ${$authStore.token}`,
          'Content-Type': 'application/json'
        }
      });

      if (!response.ok) {
        throw new Error(`Failed to load MCP tools: ${response.statusText}`);
      }

      const data = await response.json();
      mcpTools = data.tools || [];
    } catch (err) {
      error = err.message;
      console.error('Error loading MCP tools:', err);
    } finally {
      loading = false;
    }
  }

  async function executeTool(toolName, parameters) {
    try {
      loading = true;
      error = null;
      executionResult = null;

      const response = await fetch(`/api/mcp/tools/${toolName}/execute`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${$authStore.token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          arguments: parameters
        })
      });

      if (!response.ok) {
        throw new Error(`Tool execution failed: ${response.statusText}`);
      }

      const result = await response.json();
      executionResult = result;
    } catch (err) {
      error = err.message;
      console.error('Error executing tool:', err);
    } finally {
      loading = false;
    }
  }

  function selectTool(tool) {
    selectedTool = tool;
    toolParameters = {};
    executionResult = null;
    error = null;

    // Initialize parameters based on tool schema
    if (tool.inputSchema && tool.inputSchema.properties) {
      Object.keys(tool.inputSchema.properties).forEach(key => {
        toolParameters[key] = '';
      });
    }
  }

  function handleExecute() {
    if (selectedTool) {
      executeTool(selectedTool.name, toolParameters);
    }
  }

  function formatResult(result) {
    if (!result) return '';
    
    if (result.result && result.result.content) {
      return result.result.content.map(c => c.text || c.data || JSON.stringify(c)).join('\n');
    }
    
    return JSON.stringify(result, null, 2);
  }
</script>

<div class="mcp-tool-explorer">
  <div class="header">
    <h3>🔧 MCP Tools</h3>
    <button on:click={loadMCPTools} disabled={loading} class="refresh-btn">
      {loading ? '🔄' : '↻'} Refresh
    </button>
  </div>

  {#if error}
    <div class="error">
      <span class="error-icon">⚠️</span>
      {error}
    </div>
  {/if}

  <div class="tool-explorer-content">
    <!-- Tool List -->
    <div class="tool-list">
      <h4>Available Tools ({mcpTools.length})</h4>
      
      {#if loading && mcpTools.length === 0}
        <div class="loading">Loading MCP tools...</div>
      {:else if mcpTools.length === 0}
        <div class="no-tools">No MCP tools available</div>
      {:else}
        {#each mcpTools as tool}
          <div 
            class="tool-card {selectedTool?.name === tool.name ? 'selected' : ''}"
            on:click={() => selectTool(tool)}
          >
            <div class="tool-name">{tool.name}</div>
            <div class="tool-description">{tool.description}</div>
            
            {#if tool.inputSchema && tool.inputSchema.required}
              <div class="tool-requirements">
                Required: {tool.inputSchema.required.join(', ')}
              </div>
            {/if}
          </div>
        {/each}
      {/if}
    </div>

    <!-- Tool Execution Panel -->
    {#if selectedTool}
      <div class="tool-execution">
        <h4>Execute: {selectedTool.name}</h4>
        <p class="tool-description">{selectedTool.description}</p>

        <!-- Parameter Inputs -->
        {#if selectedTool.inputSchema && selectedTool.inputSchema.properties}
          <div class="parameters">
            <h5>Parameters</h5>
            {#each Object.entries(selectedTool.inputSchema.properties) as [paramName, paramSchema]}
              <div class="parameter">
                <label for={paramName}>
                  {paramName}
                  {#if selectedTool.inputSchema.required?.includes(paramName)}
                    <span class="required">*</span>
                  {/if}
                </label>
                
                {#if paramSchema.type === 'boolean'}
                  <input
                    type="checkbox"
                    id={paramName}
                    bind:checked={toolParameters[paramName]}
                  />
                {:else if paramSchema.type === 'number' || paramSchema.type === 'integer'}
                  <input
                    type="number"
                    id={paramName}
                    bind:value={toolParameters[paramName]}
                    placeholder={paramSchema.description || ''}
                  />
                {:else}
                  <input
                    type="text"
                    id={paramName}
                    bind:value={toolParameters[paramName]}
                    placeholder={paramSchema.description || ''}
                  />
                {/if}
              </div>
            {/each}
          </div>
        {/if}

        <!-- Execute Button -->
        <button 
          on:click={handleExecute}
          disabled={loading}
          class="execute-btn"
        >
          {loading ? 'Executing...' : 'Execute Tool'}
        </button>

        <!-- Execution Result -->
        {#if executionResult}
          <div class="execution-result">
            <h5>Result</h5>
            <pre class="result-content">{formatResult(executionResult)}</pre>
          </div>
        {/if}
      </div>
    {/if}
  </div>
</div>

<style>
  .mcp-tool-explorer {
    padding: 1rem;
    background: #f8f9fa;
    border-radius: 8px;
    margin: 1rem 0;
  }

  .header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;
  }

  .header h3 {
    margin: 0;
    color: #333;
  }

  .refresh-btn {
    background: #007bff;
    color: white;
    border: none;
    padding: 0.5rem 1rem;
    border-radius: 4px;
    cursor: pointer;
    font-size: 0.9rem;
  }

  .refresh-btn:hover:not(:disabled) {
    background: #0056b3;
  }

  .refresh-btn:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .error {
    background: #f8d7da;
    color: #721c24;
    padding: 0.75rem;
    border-radius: 4px;
    margin-bottom: 1rem;
    display: flex;
    align-items: center;
    gap: 0.5rem;
  }

  .tool-explorer-content {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1rem;
  }

  .tool-list h4, .tool-execution h4 {
    margin: 0 0 1rem 0;
    color: #333;
  }

  .loading, .no-tools {
    text-align: center;
    padding: 2rem;
    color: #666;
    font-style: italic;
  }

  .tool-card {
    background: white;
    border: 1px solid #ddd;
    border-radius: 6px;
    padding: 1rem;
    margin-bottom: 0.5rem;
    cursor: pointer;
    transition: all 0.2s ease;
  }

  .tool-card:hover {
    border-color: #007bff;
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  }

  .tool-card.selected {
    border-color: #007bff;
    background: #e3f2fd;
  }

  .tool-name {
    font-weight: bold;
    color: #333;
    margin-bottom: 0.25rem;
  }

  .tool-description {
    color: #666;
    font-size: 0.9rem;
    line-height: 1.4;
  }

  .tool-requirements {
    margin-top: 0.5rem;
    font-size: 0.8rem;
    color: #007bff;
    font-weight: 500;
  }

  .tool-execution {
    background: white;
    border: 1px solid #ddd;
    border-radius: 6px;
    padding: 1rem;
  }

  .parameters {
    margin: 1rem 0;
  }

  .parameters h5 {
    margin: 0 0 0.5rem 0;
    color: #333;
  }

  .parameter {
    margin-bottom: 1rem;
  }

  .parameter label {
    display: block;
    margin-bottom: 0.25rem;
    font-weight: 500;
    color: #333;
  }

  .required {
    color: #dc3545;
  }

  .parameter input {
    width: 100%;
    padding: 0.5rem;
    border: 1px solid #ddd;
    border-radius: 4px;
    font-size: 0.9rem;
  }

  .parameter input:focus {
    outline: none;
    border-color: #007bff;
    box-shadow: 0 0 0 2px rgba(0,123,255,0.25);
  }

  .execute-btn {
    background: #28a745;
    color: white;
    border: none;
    padding: 0.75rem 1.5rem;
    border-radius: 4px;
    cursor: pointer;
    font-size: 1rem;
    font-weight: 500;
    width: 100%;
    margin: 1rem 0;
  }

  .execute-btn:hover:not(:disabled) {
    background: #218838;
  }

  .execute-btn:disabled {
    opacity: 0.6;
    cursor: not-allowed;
  }

  .execution-result {
    margin-top: 1rem;
  }

  .execution-result h5 {
    margin: 0 0 0.5rem 0;
    color: #333;
  }

  .result-content {
    background: #f8f9fa;
    border: 1px solid #ddd;
    border-radius: 4px;
    padding: 1rem;
    font-size: 0.85rem;
    line-height: 1.4;
    overflow-x: auto;
    max-height: 300px;
    overflow-y: auto;
  }

  @media (max-width: 768px) {
    .tool-explorer-content {
      grid-template-columns: 1fr;
    }
  }
</style>
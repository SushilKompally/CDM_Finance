{% macro generate_empty_table_from_contract() %}
  {% set table_name = this.name %}
  
  {# Get contract columns from dbt's parsed schema - same logic as add_contract_columns #}
  {% if execute %}
    {% set all_models = graph.nodes.values() | selectattr('resource_type', 'equalto', 'model') | list %}
    {% set matching_models = all_models | selectattr('name', 'equalto', this.identifier) | list %}
    {% set model_with_schema = matching_models[0] if matching_models else none %}
    
    {% if model_with_schema and model_with_schema.columns %}
      {% set contract_columns = model_with_schema.columns.values() | list %}
      
      SELECT 
      {% for contract_col in contract_columns %}
        {# Convert contract data types to proper SQL types #}
        {% set sql_type = 'VARCHAR' %}
        {% if contract_col.data_type == 'uuid' %}
          {% set sql_type = 'VARCHAR' %}
        {% elif contract_col.data_type == 'boolean' %}
          {% set sql_type = 'BOOLEAN' %}
        {% elif contract_col.data_type == 'integer' %}
          {% set sql_type = 'INTEGER' %}
        {% elif contract_col.data_type == 'numeric' %}
          {% set sql_type = 'NUMERIC' %}
        {% elif contract_col.data_type == 'date' %}
          {% set sql_type = 'DATE' %}
        {% elif contract_col.data_type.startswith('decimal') %}
          {% set sql_type = contract_col.data_type.upper() %}
        {% endif %}
        
        CAST(NULL AS {{ sql_type }}) as {{ contract_col.name.upper() }}
        {%- if not loop.last -%},{%- endif %}
      {% endfor %}
      WHERE 1=0  -- Empty table
    {% else %}
      SELECT CAST(NULL AS INTEGER) as _placeholder WHERE 1=0
    {% endif %}
  {% else %}
    SELECT CAST(NULL AS INTEGER) as _placeholder WHERE 1=0
  {% endif %}
{% endmacro %}
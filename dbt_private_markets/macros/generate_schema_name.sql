{#
Macro: generate_schema_name

Purpose:
Control exactly how dbt assigns SQL schemas to models.

Why this macro is needed:
By default, dbt often combines:
- target schema from profiles.yml
with
- custom schema from dbt_project.yml

That behavior can produce schemas like:
- staging_staging
- staging_intermediate

For this project, we want exact schema names instead:
- staging
- intermediate
- mart

Logic:
- If no custom schema is provided, fall back to target.schema
- If a custom schema is provided, use it exactly as written
#}

{% macro generate_schema_name(custom_schema_name, node) -%}

    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}

{%- endmacro %}

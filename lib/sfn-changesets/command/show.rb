require 'sfn'
require 'hashdiff'

module Sfn
  class Command
    class ChangeSet < Command
      def parse_source(source, entity, parameters)
        case source
        when 'ParameterReference'
          param = parameters[entity]
          "Parameter #{entity}: #{param[:current]} -> #{param[:new]}"
        when 'ResourceReference'
          "Reference to Resource #{entity}"
        when 'DirectModification'
          "Direct Modification of Resource"
        end
      end

      def compose_reason(reason, parameters)
        elements = [
          reason['attribute'],
          reason['name'],
          'changed by',
          parse_source(reason['source'], reason['entity'], parameters),
        ].reject { |ele| ele == '' }
        return elements.join(' ')
      end

      def resource_diffs(changes, stack, set)
        client = cfn_client
        stack_template = provider.stack(stack).template.to_hash
        change_set_template = JSON.parse(client.get_template(
          stack_name: stack,
          change_set_name: set
        ).template_body)

        diffs = {}
        changes.each do |change|
          resource = change['resource']
          diffs[resource] = HashDiff.diff(stack_template['Resources'][resource], change_set_template['Resources'][resource])
        end
        return diffs
      end

      def display_change(change, parameters)
        ui.table(self) do
          table(border: false) do
            row(header: true) do
              column 'Action', width: 8
              column 'Resource', width: 25
              column 'Physical Id', width: 62
              column 'Type', width: 40
              column 'Replacement?', width: 15
            end
            cols = %w(action resource resource_id type replacement)
            row do
              cols.each do |attr|
                column change[attr]
              end
            end
          end
        end.display
        return
      end

      def display_details(change, parameters)
        ui.table(self) do
          table(border: false) do
            row(header: true) do
              column nil, width: 8
              column '-' * 127, width: 129
              column nil, width: 20
            end
          end
          change['reasons'].each do |detail|
            row do
              column nil
              column compose_reason(detail, parameters)
              column detail['recreation']
            end
          end
        end.display
        return
      end

      def display_diff(change, diffs)
        if diffs[change['resource']][0]
          ui.table(self) do
            table(border: false) do
              row do
                column 'Diff', width: 8
                diff = diffs[change['resource']]
                if diff[0]
                  case diff[0][0]
                  when '+'
                    color = :green
                  when '~'
                    color = 'orange'
                  when '-'
                    color = :red
                  end
                end
                column ui.color(diffs[change['resource']][0].map { |o| o.is_a?(Hash) ? o.to_json : o }.join(' '), color), width: 130 if diff[0]
              end
            end
          end.display
        end
        ui.puts "\n"
      end

      def show_set(stack, set)
        client = cfn_client
        resp = client.describe_change_set(
          stack_name: stack,
          change_set_name: set
        )

        current_params = provider.stack(stack).parameters
        parameters = {}
        resp.parameters.each do |param|
          next if param.use_previous_value
          parameters[param.parameter_key] = {
            current: current_params[param.parameter_key],
            new: param.parameter_value
          }
        end
        changes = resp.changes.map do |change|
          {
            'action' => change.resource_change.action,
            'resource' => change.resource_change.logical_resource_id,
            'resource_id' => change.resource_change.physical_resource_id,
            'type' => change.resource_change.resource_type,
            'replacement' => change.resource_change.replacement,
            'reasons' => change.resource_change.details.map do |detail|
              {
                'attribute' => detail.target.attribute.gsub('Properties', 'Property'),
                'recreation' => detail.target.requires_recreation,
                'name' => detail.target.name.to_s,
                'evaluation' => detail.evaluation,
                'source' => detail.change_source,
                'entity' => detail.causing_entity.to_s
              }
            end
          }
        end
        diffs = resource_diffs(changes, stack, set)
        changes.sort_by! { |change| change['action'] }
        #cols = %w(action resource reasons)
        ui.info "Created: #{resp.creation_time}"
        ui.info "Status: #{resp.status}"
        ui.info "Execution Status: #{resp.execution_status}"
        ui.info "Resource Changes:"
        changes.each do |change|
          display_change(change, parameters)
          display_details(change, parameters)
          display_diff(change, diffs)
        end
        return
      end
    end
  end
end

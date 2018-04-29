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
            'type' => change.resource_change.resource_type,
            'reasons' => change.resource_change.details.map do |detail|
              {
                'attribute' => detail.target.attribute.gsub('Properties', 'Property'),
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
        cols = %w(action resource reasons)
        ui.info "Created: #{resp.creation_time}"
        ui.info "Status: #{resp.status}"
        ui.info "Execution Status: #{resp.execution_status}"
        ui.info "Changes:"
        ui.table(self) do
          table(border: false) do
            row(header: true) do
              column 'Action', width: 8
              column 'Resource', width: width_val = changes.map { |e| e['type'].to_s.length }.max + 2
              column 'Reason(s)', width: 90
            end
            cols.delete('reasons')
            changes.each do |change|
              lines = change['reasons'].size - 2
              row do
                cols.each do |attr|
                  column change[attr]
                end
                unless change['reasons'].empty?
                  reason = change['reasons'][0]
                  column compose_reason(reason, parameters)
                end
              end
              row do
                column nil
                column change['type']
                if change['reasons'].size > 1
                  column compose_reason(change['reasons'][1], parameters)
                end
              end
              lines.times do |i|
                i = i + 2
                row do
                  cols.each do |attr|
                    column nil
                  end
                  reason = change['reasons'][i]
                  column compose_reason(reason, parameters)
                end
              end
              if diffs[change['resource']][0]
                row do
                  diff = diffs[change['resource']]
                  if diff[0]
                    case diff[0][0]
                    when '+'
                      color = :green
                    when '~'
                      color = 'gold'
                    when '-'
                      color = :red
                    end
                  end
                  column nil
                  column 'Diff'
                  column ui.color(diffs[change['resource']][0].join(' '), color) if diff[0]
                end
              end
              row do
                column nil
              end
            end
          end
        end.display
        return
      end
    end
  end
end

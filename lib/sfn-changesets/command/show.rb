require 'sfn'

module Sfn
  class Command
    class ChangeSet < Command
      def compose_reason(reason)
        elements = [
          reason['attribute'],
          reason['name'],
          'changed by',
          reason['evaluation'],
          'Eval of',
          reason['source'],
          reason['entity']
        ].reject { |ele| ele == '' }
        return elements.join(' ')
      end

      def show_set(stack, set)
        client = cfn_client
        resp = client.describe_change_set(
          stack_name: stack,
          change_set_name: set
        )
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
        changes.sort_by! { |change| change['action'] }
        cols = %w(action resource reasons)
        ui.info "Created: #{resp.creation_time}"
        ui.info "Status: #{resp.status}"
        ui.info "Execution Status: #{resp.execution_status}"
        ui.info "Changes:"
        ui.table(self) do
          table(border: false) do
            row(header: true) do
              cols.each do |attr|
                width_val = changes.map { |e| e[attr].to_s.length }.push(attr.length).max + 2
                width_val = width_val > 96 ? 96 : width_val < 8 ? 8 : width_val
                column attr.split('_').map(&:capitalize).join(' '), :width => width_val
              end
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
                  column compose_reason(reason)
                end
              end
              row do
                column nil
                column change['type']
                if change['reasons'].size > 1
                  column compose_reason(change['reasons'][1])
                end
              end
              lines.times do |i|
                i = i + 2
                row do
                  cols.each do |attr|
                    column nil
                  end
                  reason = change['reasons'][i]
                  column compose_reason(reason)
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

require 'aws-sdk-cloudformation'
require 'sfn'

module Sfn
  class Command
    class ChangeSet < Command
      def debug
        puts 'DEBUG'
      end
      def list_sets(stack)
        client = cfn_client
        resp = client.list_change_sets(stack_name: stack)
        sets = resp.summaries
        unless sets.empty?
          stack_change_sets = sets.map do |set|
            {
              'change_set_name' => set.change_set_name,
              'creation_time' => set.creation_time,
              'status' => set.status,
              'execution_status' => set.execution_status
            }
          end

          cols = stack_change_sets.first.keys

          ui.table(self) do
            table(border: false) do
              row(header: true) do
                cols.each do |attr|
                  width_val = stack_change_sets.map { |e| e[attr].to_s.length }.push(attr.length).max + 2
                  width_val = width_val > 70 ? 70 : width_val < 20 ? 20 : width_val
                  column attr.split('_').map(&:capitalize).join(' '), :width => width_val
                end
              end
              stack_change_sets.each do |set|
                row do
                  cols.each do |attr|
                    column set[attr]
                  end
                end
              end
            end
          end.display
        else
          ui.info "Stack #{ui.color(stack, 'gold')} has no Change Sets"
        end
        return
      end
    end
  end
end

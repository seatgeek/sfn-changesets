require 'sfn'

module Sfn
  class Command
    class ChangeSet < Command
      def apply_set(stack, set)
        client = cfn_client
        resp = client.execute_change_set(
          stack_name: stack,
          change_set_name: set
        )
        if config[:poll]
          poll_stack = provider.stacks.get(stack)
          poll_stack(stack)
          if poll_stack.reload.state == :update_complete
            ui.info "Change Set applied: #{ui.color('SUCCESS', :green)}"
            namespace.const_get(:Describe).new({:outputs => true}, [stack]).execute!
          else
            ui.fatal "Change Set #{ui.color(set, :bold)}: #{ui.color('FAILED', :red, :bold)}"
            raise 'Stack did not reach a successful update completion state.'
          end
        else
          ui.warn 'Stack state polling has been disabled.'
          ui.info "Initialized apply of Change Set #{ui.color(set, :green)} to #{ui.color(stack, :green)}"
        end
        return
      end
    end
  end
end

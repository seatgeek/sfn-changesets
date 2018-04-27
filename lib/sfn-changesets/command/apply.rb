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
        return
      end
    end
  end
end

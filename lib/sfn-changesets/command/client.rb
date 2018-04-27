require 'aws-sdk-cloudformation'
require 'sfn'

module Sfn
  class Command
    class ChangeSet < Command
      def cfn_client
        creds = config[:credentials]
        client = Aws::CloudFormation::Client.new(
          region: creds[:aws_region],
          access_key_id: creds[:aws_access_key_id],
          secret_access_key: creds[:aws_secret_access_key]
        )
        return client
      end
    end
  end
end

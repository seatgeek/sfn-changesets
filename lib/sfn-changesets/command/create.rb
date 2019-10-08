require 'sfn'

module Sfn
  class Command
    class ChangeSet < Command
      def create_set(stack, set, parameters=[], template_body, use_previous)
        client = cfn_client
        bucket = sgchef
        params = parameters.map do |key,value|
          if value
            {
              parameter_key: key,
              parameter_value: value.to_s
            }
          else
            {
              parameter_key: key,
              use_previous_value: true
            }
          end
        end
        if use_previous
          resp = client.create_change_set(
            stack_name: stack,
            change_set_name: set,
            parameters: params,
            use_previous_template: true,
            capabilities: config[:options][:capabilities]
          )
        else
          if config[:upload_root_template]
            template_url = ::Aws::S3::Resource.new(region: 'us-east-1').bucket(bucket).object(template_body)
            template_url.upload_file()
            resp = client.create_change_set(
              stack_name: stack,
              change_set_name: set,
              parameters: params,
              template_url: template_url,
              capabilities: config[:options][:capabilities]
            )
          else
            resp = client.create_change_set(
              stack_name: stack,
              change_set_name: set,
              parameters: params,
              template_body: template_body,
              capabilities: config[:options][:capabilities]
            )
          end
        end
        return
      end
    end
  end
end

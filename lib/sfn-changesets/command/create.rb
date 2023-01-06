require 'sfn'

module Sfn
  class Command
    class ChangeSet < Command
      def create_set(stack, set, parameters=[], template_body, use_previous, type)
        client = cfn_client
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
        tags = config[:options][:tags].map do |key,value|
          {
            key: key,
            value: value.to_s
          }
        end
        if use_previous
          resp = client.create_change_set(
            stack_name: stack,
            change_set_name: set,
            parameters: params,
            use_previous_template: true,
            capabilities: config[:options][:capabilities],
            change_set_type: "UPDATE",
            tags: tags
          )
        else
          if config[:upload_root_template]
            upload_s3 = Aws::S3::Client.new()
            upload_s3.put_object(
              body: template_body,
              bucket: config[:nesting_bucket],
              key: "#{config[:nesting_prefix]}/#{stack}_#{set}.json"
            )

            resp = client.create_change_set(
              stack_name: stack,
              change_set_name: set,
              parameters: params,
              template_url: "https://s3.amazonaws.com/#{config[:nesting_bucket]}/#{config[:nesting_prefix]}/#{stack}_#{set}.json",
              capabilities: config[:options][:capabilities],
              change_set_type: type,
              tags: tags
            )
          else
            resp = client.create_change_set(
              stack_name: stack,
              change_set_name: set,
              parameters: params,
              template_body: template_body,
              capabilities: config[:options][:capabilities],
              change_set_type: type,
              tags: tags
            )
          end
        end
        return
      end
    end
  end
end

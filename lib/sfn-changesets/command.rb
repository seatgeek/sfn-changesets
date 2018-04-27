require 'sfn-changesets'
require 'aws-sdk-cloudformation'
require 'sfn-changesets/command/client'
require 'sfn-changesets/command/apply'
require 'sfn-changesets/command/create'
require 'sfn-changesets/command/destroy'
require 'sfn-changesets/command/list'
require 'sfn-changesets/command/show'

module Sfn
  class Command
    class ChangeSet < Command
      include Sfn::CommandModule::Base
      include Sfn::CommandModule::Template
      include Sfn::CommandModule::Stack

      def execute!
        name_required!
        sub_command = name_args[0]
        stack_name = name_args[1]
        set_name = name_args[2]
        unless %w(create list show apply destroy).include? sub_command
          raise ArgumentError, 'sfn changeset requires a subcommand (create, list, describe, apply, destroy).'
        else
          if (%w(create show apply destroy).include? sub_command) && set_name.nil?
            raise ArgumentError, "#{sub_command} requires a set name argument: sfn changeset #{sub_command} <stack> <set>"
          end
        end
        root_stack = stack(stack_name)
        api_action!(api_stack: root_stack) do
          case sub_command

          when 'create'
            current_params = provider.stack(stack_name).parameters
            if config[:file]
              if provider.stack(stack_name).outputs
                compile_params = provider.stack(stack_name).outputs.detect do |output|
                output.key == 'CompileState'
              end
            end
              if compile_params
                compile_params = MultiJson.load(compile_params.value)
                config[:compile_parameters] = compile_params
              end
              template = load_template_file
              use_previous = false
            else
              template = provider.stack(stack_name).template
              use_previous = true
            end
            populate_parameters!(template, :current_parameters => current_params)
            params = {}

            config_root_parameters.each do |key,value|
              if value == current_params[key]
                params[key] = false
              else
                params[key] = value
              end
            end

            ui.info "Creating Change Set #{ui.color(set_name, 'gold')} for #{ui.color(root_stack.name, 'gold')}"

            template_body = parameter_scrub!(template_content(template, :scrub)).to_json
            create_set(stack_name, set_name, params, template_body, use_previous)

            ui.info "Created Change Set #{ui.color(set_name, 'gold')} for #{ui.color(root_stack.name, 'gold')}"

          when 'list'
            ui.info "Listing Change Sets from stack #{ui.color(root_stack.name, 'gold')}"
            list_sets(stack_name)

          when 'show'
            ui.info "Showing Change Set #{ui.color(set_name, 'gold')} from #{ui.color(root_stack.name, 'gold')}"
            show_set(stack_name, set_name)

          when 'apply'
            ui.info "Applying Change Set #{ui.color(set_name, 'gold')} to #{ui.color(root_stack.name, 'gold')}"
            apply_set(stack_name, set_name)

          when 'destroy'
            ui.info "Destroying Change Set #{ui.color(set_name, 'gold')} from stack #{ui.color(root_stack.name, 'gold')}"
            destroy_set(stack_name, set_name)

          end
        end
      end
    end
  end
end

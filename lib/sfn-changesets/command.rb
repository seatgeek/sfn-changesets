require 'sfn-changesets'
require 'aws-sdk-cloudformation'
require 'sfn-changesets/command/client'
require 'sfn-changesets/command/apply'
require 'sfn-changesets/command/create'
require 'sfn-changesets/command/destroy'
require 'sfn-changesets/command/list'
require 'sfn-changesets/command/show'
require 'sfn-changesets/config/parameter_file'

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
        begin
          root_stack = stack(stack_name)
          if root_stack.complete?
            update = true
          else
            update = false
          end
        rescue Miasma::Error::ApiError::RequestError
          update = false
        end

        api_action!(api_stack: root_stack) do
          case sub_command

          when 'create'
            if update
              current_params = provider.stack(stack_name).parameters
              load_stack_file(stack_name)
            end
            # Collect Current Compile Time Parameters then Compile Template
            if config[:file]
              if update
                if provider.stack(stack_name).outputs
                  compile_params = provider.stack(stack_name).outputs.detect do |output|
                    output.key == 'CompileState'
                  end
                end
              end
              if compile_params
                compile_params = MultiJson.load(compile_params.value)
                config[:compile_parameters] = compile_params
              end
              template = load_template_file
              template_body = parameter_scrub!(template_content(template, :scrub)).to_json
              use_previous = false
            else
              if update
                template = provider.root_stack.template
                template_body = template
                use_previous = true
              else
                template = load_template_file
                template_body = parameter_scrub!(template_content(template, :scrub)).to_json
              end
            end

            unless update
              root_stack = provider.connection.stacks.build(
                config.fetch(:options, Smash.new).dup.merge(
                  :name => stack_name,
                  :template => template_content(template),
                  :parameters => Smash.new,
                )
              )
            end

            apply_stacks!(root_stack)

            if current_params
              default_params = root_stack.parameters.merge(current_params)
            else
              default_params = root_stack.parameters
            end

            populate_parameters!(template, :current_parameters => default_params)

            params = {}

            if current_params
              config_root_parameters.each do |key,value|
                if value == current_params[key]
                  params[key] = false
                else
                  params[key] = value
                end
              end
            else
              params = config_root_parameters
            end

            ui.info "Creating Change Set #{ui.color(set_name, 'gold')} for #{ui.color(root_stack.name, 'gold')}"

            create_set(stack_name, set_name, params, template_body, use_previous, update ? 'UPDATE' : 'CREATE')
            if set_failed_no_change?(stack_name, set_name)
              ui.warn "No Changes Detected. Change Set #{ui.color(set_name, 'gold')} could not be created for #{ui.color(root_stack.name, 'gold')}"
              destroy_set(stack_name, set_name)
            else
              ui.info "Created Change Set #{ui.color(set_name, 'gold')} for #{ui.color(root_stack.name, 'gold')}"
            end

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

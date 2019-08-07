def load_stack_file(stack_name)
  root_path = config.fetch(:sfn_parameters, :directory, 'stacks')
  paths = Dir.glob(File.join(root_path, "#{stack_name}.yml")).map(&:to_s)
  if(paths.size > 1)
    raise ArgumentError.new "Multiple parameter file matches encountered! (#{paths.join(', ')})"
  elsif(paths.empty?)
    Smash.new
  else
    stack_file = Bogo::Config.new(paths.first).data
    config[:compile_parameters] = stack_file[:compile_parameters] || Smash.new
    config[:parameters] = stack_file[:parameters] || Smash.new
    config[:file] = stack_file[:template]
    config[:apply_stacks] = stack_file[:apply_stacks] || []
    config[:apply_mapping] ||= Smash.new
    config[:options][:tags] ||= Smash.new
  end
end

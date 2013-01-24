load 'deploy'

P, S = ARGV[2], ARGV[1]

# compatibility hacks for recipes
set :webistrano_project, P
set :webistrano_stage,   S

load 'deploy'
# Uncomment if you are using Rails' asset pipeline
# load 'deploy/assets'

def project_path project, *args
  (['config/deploy/projects', project] + args).join '/'
end

def recipe_path recipe
  'config/deploy/recipes/%s.recipe' % recipe
end

def param_files project, stage
  Dir.glob(project_path(*[project, stage, 'params', '*'].compact))
end

def load_params project, stage
  params = {}
  [nil, stage].each do |stage|
    (param_files project, stage).each do |path|
      params[File.basename path] = path
    end
  end
  params.each_pair do |name, path|
    set name, (File.read path).chomp
  end
end

def load_host role, spec
  host, *attrs = spec.split ' '
  hash = {}
  attrs.each do |attr|
    hash[attr.to_sym] = true
  end
  server host, role, hash
end

def load_roles project, stage
  Dir.glob(project_path(project, stage, 'roles/*')).each do |path|
    role = File.basename path
    File.open path, 'r' do |fd|
      fd.readlines.each do |line|
        load_host role, line.chomp
      end
    end
  end
end

def load_recipes project, stage
  File.open(project_path(project, stage, 'recipes'), 'r') do |fd|
    fd.readlines.each do |line|
      load recipe_path(line.chomp)
    end
  end
end

load_params P, S
load_roles P, S
load_recipes P, S


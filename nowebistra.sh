#!/bin/sh

# Copyright (c) Roman Neuhauser
# Distributed under the MIT license (see LICENSE file)

set -o errexit
set -o nounset
set -o posix

q()
{
  if test $# -eq 1; then
    set -- -e "$@"
  fi
  sudo mysql -D webistrano -sr "$@"
}

outdir=${1-output}
mkdir -p $outdir
cd $outdir

# configuration parameters, project-wide
q <<-'SQL' |
  SELECT
    LOWER(REPLACE(p.name, ' ', '_')) path
  , cp.name variable
  , cp.value value
  FROM configuration_parameters cp
  , projects p
  WHERE cp.project_id = p.id
    AND cp.type = 'ProjectConfiguration'
SQL
while read row; do
  set -- $row
  path="projects/$1/params"
  var="$2"
  shift 2
  val="$@"
  mkdir -p $path
  echo $val > $path/$var
done

# configuration parameters, project-stage-specific
q <<-'SQL' |
SELECT LOWER(REPLACE(CONCAT_WS('/', p.name, s.name), ' ', '_')) path
, cp.name variable
, cp.value value
FROM configuration_parameters cp
, projects p
, stages s
WHERE cp.stage_id = s.id
  AND s.project_id = p.id
  AND cp.type = 'StageConfiguration'
SQL
while read row; do
  set -- $row
  path="projects/$1/params"
  var="$2"
  shift 2
  val="$@"
  mkdir -p $path
  echo $val > $path/$var
done

# host roles
q <<-'SQL' |
  SELECT
    LOWER(REPLACE(CONCAT_WS('/', p.name, s.name), ' ', '_')) path
  , r.name role
  , h.name host
  , CASE `primary` WHEN 0 THEN '' ELSE 'primary' END prim
  , CASE no_release WHEN 0 THEN '' ELSE 'no_release' END norel
  FROM projects p, stages s, roles r, hosts h
  WHERE p.id = s.project_id
    AND r.stage_id = s.id
    AND r.host_id = h.id
  ORDER BY path, host
SQL
while read row; do
  set -- $row
  rpath=projects/$1/roles
  role=$2
  shift 2
  host="$@"
  mkdir -p $rpath
  echo $host >> $rpath/$role
done

# recipes
mkdir -p recipes
q "SELECT id FROM recipes;" | while read id; do
  {
    {
      q "SELECT name FROM recipes WHERE id = $id;"
      q "SELECT REPLACE(description, '\r', '') FROM recipes WHERE id = $id;"
    } | sed 's/^/# /'
    echo
    q "SELECT REPLACE(body, '\r', '') FROM recipes WHERE id = $id;"
  } > recipes/$id.recipe
done

# recipes used in each project-stage
q <<-'SQL' |
  SELECT
    LOWER(REPLACE(CONCAT_WS('/', p.name, s.name), ' ', '_')) path
  , rs.recipe_id
  FROM projects p, stages s, recipes_stages rs
  WHERE p.id = s.project_id
    AND rs.stage_id = s.id
  ORDER BY path, recipe_id
SQL
while read row; do
  set -- $row
  path=projects/$1
  recipe=$2
  mkdir -p $path
  echo $recipe >> $path/recipes
done


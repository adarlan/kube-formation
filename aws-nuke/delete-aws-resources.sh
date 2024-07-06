#!/bin/bash
set -e
cd $(mktemp -d)

export AWS_ACCESS_KEY_ID=$(cat /secrets/aws_access_key_id)
export AWS_SECRET_ACCESS_KEY=$(cat /secrets/aws_secret_access_key)
export AWS_DEFAULT_REGION=$(cat /secrets/aws_region)
export AWS_ACCOUNT_ID=$(cat /secrets/aws_account_id)

# --resource-types
resource_types=$(echo "$2" | tr ' ' '\n')

# --tag
tag_name="${4%%=*}"
tag_value="${4#*=}"

# create nuke config file
cat <<-EOT > nuke-config.yaml
regions:
  - $AWS_DEFAULT_REGION
  - global
account-blocklist:
  - "999999999999"
accounts:
  "$AWS_ACCOUNT_ID":
EOT

# include listed resource types and filter by tag
cat <<-EOT >> nuke-config.yaml
    filters:
EOT
for resource_type in $(aws-nuke resource-types); do
if echo "$resource_types" | grep -E "^$resource_type$" > /dev/null; then
cat <<-EOT >> nuke-config.yaml
      $resource_type:
      - property: "tag:$tag_name"
        value: "$tag_value"
        invert: true
EOT
fi
done

# exclude resource types not listed
cat <<-EOT >> nuke-config.yaml
resource-types:
  excludes:
EOT
for resource_type in $(aws-nuke resource-types); do
if ! echo "$resource_types" | grep -E "^$resource_type$" > /dev/null; then
cat <<-EOT >> nuke-config.yaml
  - $resource_type
EOT
fi
done

echo "## Running aws-nuke in dry-run mode"; (
  set -exo pipefail
  aws-nuke --config nuke-config.yaml --quiet --force --force-sleep 0 | tee dry-run.log
)

# check if there are resources to remove
if ! cat dry-run.log | grep -E '.*\- would remove$' > /dev/null; then
  echo "## No nukeable resources found"
  exit 0
fi

# list resources to remove
echo; echo "AWS resources to remove"
cat dry-run.log | grep -E '.*\- would remove$' | awk -F ' - ' '{ printf "%-16s | %-32s | %s\n", $1, $2, $3 }'

# TODO ask for confirmation?
# _confirm "Run aws-nuke with '--no-dry-run' option?" \
# "Remove AWS resources ($(echo "$resource_types" | tr '\n' ' ')) that have the tag \"$tag_name=$tag_value\"." \
# "Before confirming, pay attention to the list of resources above, as aws-nuke may not filter some resources properly."

echo; echo "Removing AWS resources"; (
  set -ex
  aws-nuke --config nuke-config.yaml --quiet --no-dry-run
)
# (set -exo pipefail; aws-nuke --config nuke-config.yaml --quiet --no-dry-run | tee no-dry-run.log)
# aws-nuke --config nuke-config.yaml --quiet --no-dry-run --force --force-sleep 3 | tee no-dry-run.log

# TODO check if removed all (this is actually checking if removed at least one)
# if ! cat no-dry-run.log | grep -E '.*\- removed$' > /dev/null; then
#   echo "## No resources were removed"
#   exit 1
# fi

# list removed resources
# echo; echo "## Removed AWS resources"
# cat no-dry-run.log | grep -E '.*\- removed$' | awk -F ' - ' '{ printf "%-16s | %-32s | %s\n", $1, $2, $3 }'

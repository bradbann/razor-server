# -*- encoding: utf-8 -*-
# this is required because of the use of eval interacting badly with require_relative
require 'razor/acceptance/utils'
require 'yaml'
confine :except, :roles => %w{master dashboard database frictionless}

test_name 'QA-1820 - C59740 - create-hook with same name as existing hook'
step 'https://testrail.ops.puppetlabs.net/index.php?/cases/view/59740'

hook_dir      = '/opt/puppetlabs/server/apps/razor-server/share/razor-server/hooks'
hook_type     = 'hook_type_1'
hook_name     = 'hookName1'
hook_path     = "#{hook_dir}/#{hook_type}.hook"

configuration_file =<<-EOF
---
value:
  description: "The current value of the hook"
  default: 0
foo:
  description: "The current value of the hook"
  default: defaultFoo
bar:
  description: "The current value of the hook"
  default: defaultBar

EOF

teardown do
  agents.each do |agent|
    on(agent, "razor delete-hook --name #{hook_name}")
  end
end

agents.each do |agent|
  with_backup_of(agent, hook_dir) do
    step "Create hook type"
    on(agent, "mkdir -p #{hook_path}")
    create_remote_file(agent,"#{hook_path}/configuration.yaml", configuration_file)
    on(agent, "chmod +r #{hook_path}/configuration.yaml")
    on(agent, "razor create-hook --name #{hook_name}" \
              " --hook-type #{hook_type} -c value=5 -c foo=newFoo -c bar=newBar")

    step 'Verify if the hook is successfully created:'
    on(agent, "razor -u https://razor-razor@#{agent}:8151/api hooks") do |result|
      assert_match(/#{hook_name}/, result.stdout, 'razor create-hook failed')
    end

    # due to RAZOR-491, this is NOT a invalid test case, and the same create-hook command
    # with same parameters will result in a single entity.
    step "Create a new hook with same name as existing hook #{hook_name}"
    on(agent, "razor create-hook --name #{hook_name}" \
              " --hook-type #{hook_type} -c value=5 -c foo=newFoo -c bar=newBar")

    # Run the command again with different config parameters and verify it reports a conflict.
    step "Create a hook with same name and different config parameters"
    on(agent, "razor create-hook --name #{hook_name}" \
              " --hook-type #{hook_type} -c value=7 -c foo=differentfoo -c bar=differentBar", \
              :acceptable_exit_codes => [1]) do |result|
      assert_match(/error: The hook #{hook_name} already exists, and the configuration fields do not match/, result.stdout, 'Test failed')
    end
  end
end

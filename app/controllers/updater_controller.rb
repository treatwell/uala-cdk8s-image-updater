require 'fileutils'
require 'date'
require 'erb'
require 'yaml'
require 'git'
require 'deep_merge'
require 'colorize'
require 'retriable'

class UpdaterController
  @git_client = nil
  @applications_conf = []
  @applications_to_update = []

  def step_0
    puts "\nStep 0: check required params...".light_yellow
    if !ENV.key?('GIT_IAC_REPO')
      puts '[ERROR] GIT_IAC_REPO environment variable is missing!'.red
      exit 1
    end

    if !ENV.key?('GIT_IAC_TOKEN')
      puts '[ERROR] GIT_IAC_TOKEN environment variable is missing!'.red
      exit 1
    end

    if !ENV.key?('GIT_SOURCE_REPO')
      puts '[ERROR] GIT_SOURCE_REPO environment variable is missing!'.red
      exit 1
    end

    if !ENV.key?('GIT_SOURCE_BRANCH')
      puts '[ERROR] GIT_SOURCE_BRANCH environment variable is missing!'.red
      exit 1
    end

    if !ENV.key?('GIT_SOURCE_COMMIT_SHA') && !ENV.key?('GIT_SOURCE_TAG')
      puts '[ERROR] GIT_SOURCE_COMMIT_SHA AND GIT_SOURCE_TAG environment variables are missing!'.red
      exit 1
    end
    puts 'OK.'
    puts "\n#################################################################".green
    puts "\nWe are looking for:\n"
    puts "GIT REPO: #{ENV['GIT_SOURCE_REPO'].green}"
    puts "GIT BRANCH: #{ENV['GIT_SOURCE_BRANCH'].green}"

    if ENV.key?('FORCE_UPDATE_APP')
      puts "\nWe want to update only the app: #{ENV['FORCE_UPDATE_APP'].green}"
    end

    if ENV.key?('GIT_SOURCE_TAG')
      puts "\nWe want to update images to tag release: #{ENV['GIT_SOURCE_TAG'].green}"
    elsif ENV.key?('GIT_SOURCE_COMMIT_SHA')
      puts "\nWe want to update images to commit: #{ENV['GIT_SOURCE_COMMIT_SHA'].green}"
    end
    puts "\nWe are updating IAC REPO: #{ENV['GIT_IAC_REPO'].green}"
    if ENV.key?('GIT_IAC_BRANCH')
      puts "ON BRANCH: #{ENV['GIT_IAC_BRANCH'].green}"
    end
    puts "\n#################################################################".green
  end

  def step_1
    puts "\nStep 1: Prepare environment...".light_yellow
    ENV['GITHUB_TOKEN'] = ENV['GIT_IAC_TOKEN']
    FileUtils.rm_rf('iac-repo')
    puts 'OK.'
  end

  def step_2
    puts "\nStep 2: Clone iac-repo...".light_yellow
    @git_client = Git.clone(
      "https://#{ENV['GIT_IAC_TOKEN']}@#{ENV['GIT_IAC_REPO']}",
      'iac-repo',
      { branch: ENV['GIT_IAC_BRANCH'] }
    )
    puts 'OK.'
  end

  def step_3
    puts "\nStep 3: Get applications available in iac-repo...".light_yellow

    @applications_conf = {}

    Dir.glob('iac-repo/applications*.yaml').each do |file|
      File.open(file, 'r') do |yaml_file|
        yaml_conf = YAML.safe_load(ERB.new(File.read(yaml_file)).result)
        @applications_conf.deep_merge!(yaml_conf)
      end
    end

    # puts @applications_conf.to_yaml
    puts 'OK.'
  end

  def check_type(value, path)
    case value
    when Hash
      iHash(value, path)
    when Array
      iArray(value, path)
    end
  end

  def iHash(hash, path)
    git_repo_found = false
    git_branch_found = false
    git_only_tags_found = false
    hash.each_pair do |k, v|
      # puts "HASH: #{k}"
      if k == 'git_repo' && v == ENV['GIT_SOURCE_REPO']
        git_repo_found = true
      end
      if k == 'branch'
        regexp = Regexp.new("^#{v}$")
        if regexp.match?(ENV['GIT_SOURCE_BRANCH'])
          git_branch_found = true
        end
      end
      if k == 'only_tags' && v == true
        git_only_tags_found = true
      end
      check_type(v, "#{path}/#{k}")
    end

    if git_repo_found && git_branch_found
      if git_only_tags_found && !ENV.key?('GIT_SOURCE_TAG')
        # this app cannot be added because require a tag release.
      elsif !ENV.key?('FORCE_UPDATE_APP') || ENV['FORCE_UPDATE_APP'] == hash['name']
        hash['path'] = path
        @applications_to_update.push(hash)
      end
      # puts "APP FOUND: \npath:#{path}\n#{hash.to_yaml}\n\n"
    end
  end

  def iArray(array, path)
    array.each do |v|
      # puts "ARRAY!" #{v}"
      check_type(v, path)
    end
    path
  end

  def step_4
    puts "\nStep 4: Find applications that match the current repo and branch...".light_yellow

    @applications_to_update = []
    check_type(@applications_conf, '')

    if @applications_to_update.count == 0
      puts "\nNothing to update, exit.".green

      puts "\nDONE!\n".blue
      exit(0)
    end

    puts "Found #{@applications_to_update.count} applications to update:".green
    puts @applications_to_update.map { |e| e['path'] + ' - ' + e['name'] }
  end

  def step_5
    puts "\nStep 5: Update applications images files with new tags...".light_yellow

    @applications_to_update.each do |app|
      # puts app
      File.open("iac-repo/applications/#{app['path']}/applications_settings.yaml", 'r+') do |yaml_file|
        yaml_content = YAML.safe_load(yaml_file.read)
        # puts app
        if yaml_content[app['name']]
          yaml_content[app['name']]['image'] = app['image']
          print "#{app['path']} - #{app['name']}: #{app['image'].green}\n"
        end
        # puts yaml_content.to_yaml
        yaml_file.rewind
        yaml_file.write(yaml_content.to_yaml)
        yaml_file.truncate(yaml_file.pos)
      end
    end
  end

  def step_6
    puts "\nStep 6: Push edited files to iac repo...".light_yellow

    push_branch = "#{ENV['GIT_SOURCE_REPO']}-#{ENV['GIT_SOURCE_BRANCH']}"
    if ENV.key?('GIT_SOURCE_TAG')
      push_branch += "-#{ENV['GIT_SOURCE_TAG']}"
    else
      push_branch += "-#{ENV['GIT_SOURCE_COMMIT_SHA']}"
    end
    push_branch += "-#{DateTime.now.strftime('%s')}"

    if (ENV.key?('GIT_SOURCE_TAG') &&
       (!ENV.key?('GIT_IAC_DISABLE_TAG_PR') || ENV['GIT_IAC_DISABLE_TAG_PR'] != 'true')) ||
       ENV['GIT_IAC_FORCE_PR'] == 'true'
      if ENV['GIT_DRY_RUN'] == 'true'
        puts "\n[DRY_RUN] Added edited files to a new branch: #{push_branch.green}."
        puts "\n[DRY_RUN] No PR will be created in dryrun mode."
        return
      end

      @git_client.branch(push_branch)
      @git_client.branch(push_branch).checkout
      @git_client.commit_all("[IMAGE_UPDATER] #{push_branch}") # set branch name as commit message
      @git_client.push('origin', push_branch)

      puts "\nAdded edited files to a new branch: #{push_branch.green}."
      puts "\nCreating a PR..."
      puts `cd iac-repo && gh pr create #{ENV.key?('GIT_IAC_BRANCH') ? '--base ' + ENV['GIT_IAC_BRANCH'] : ''} --title "[IMAGE_UPDATER] #{push_branch}" --body ""`
    else
      if ENV['GIT_DRY_RUN'] == 'true'
        puts "\n[DRY_RUN] Edited files have been pushed to #{@git_client.current_branch} branch.".green
        return
      end

      on_retry = proc do |exception, try, elapsed_time, next_interval|
        puts "#{exception.class}: '#{exception.message}' - #{try} tries in #{elapsed_time} seconds and #{next_interval} seconds until the next try.".red
      end
      begin
        @git_client.checkout(@git_client.current_branch)
        @git_client.commit_all("[IMAGE_UPDATER] #{push_branch}")
        # Match on each exception that doesn't contains "Your branch is up to date"
        ::Retriable.retriable(on: { Git::GitExecuteError => /^((?!Your branch is up to date).)*$/ }, on_retry: on_retry, tries: 10, base_interval: 1) do
          @git_client.pull('origin', @git_client.current_branch)
          @git_client.push('origin', @git_client.current_branch)
        end
      rescue Git::GitExecuteError => e
        if e.message.include?('Your branch is up to date')
          puts "\nEdited files match with last version on #{@git_client.current_branch} branch.".green
        else
          raise e
        end
      end

      puts "\nEdited files have been pushed to #{@git_client.current_branch} branch.".green
    end
  end

  def step_7
    return unless ENV.key?('IAC_DEPLOYER_FILE')

    puts "\nStep 7: Generate config for CDK8S Deployer...".light_yellow
    # puts @applications_to_update
    environments = @applications_to_update
      .group_by { |a| a['path'].sub('/environments/', '') }
      .map do |environment, applications|

      { environment => applications.map { |a| a['name'] } }
    end

    conf = {}
    conf['deploy_environments'] = environments
    puts conf.to_yaml

    File.open(ENV['IAC_DEPLOYER_FILE'], 'w') do |file|
      file.write(conf.to_yaml)
    end

    puts 'OK.'
  end
end

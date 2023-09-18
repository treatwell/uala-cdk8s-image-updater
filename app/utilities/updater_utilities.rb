module Utilities
  extend self

  def check_type(value, path, applications_to_update)
    case value
    when Hash
      iHash(value, path, applications_to_update)
    when Array
      iArray(value, path, applications_to_update)
    end
  end

  def iHash(hash, path, applications_to_update)
    git_repo_found = false
    git_branch_found = false
    git_only_tags_found = false

    hash.each_pair do |key, value|
      puts "HASH: #{key}" if ENV['DEBUG'] == 'true'

      case key
      when 'git_repo'
        git_repo_found = true if value == ENV['GIT_SOURCE_REPO']
      when 'branch'
        regexp = Regexp.new("^#{value}$")
        git_branch_found = true if regexp.match?(ENV['GIT_SOURCE_BRANCH'])
      when 'only_tags'
        git_only_tags_found = true if value == true
      end

      check_type(value, "#{path}/#{key}", applications_to_update)
    end

    if git_repo_found &&
      (git_branch_found || git_only_tags_found) &&
      (!ENV.key?('FORCE_UPDATE_APP') || ENV['FORCE_UPDATE_APP'] == hash['name']) &&
      (
        (!ENV['GIT_SOURCE_TAG'].to_s.strip.empty? && git_only_tags_found) ||
        (ENV['GIT_SOURCE_TAG'].to_s.strip.empty? && !git_only_tags_found)
      )
      hash['path'] = path
      applications_to_update.push(hash)

      puts "APP FOUND: \npath:#{path}\n#{hash.to_yaml}\n\n"  if ENV['DEBUG'] == 'true'
    end
  end

  def iArray(array, path, applications_to_update)
    array.each do |v|
      puts "ARRAY! #{v}"  if ENV['DEBUG'] == 'true'

      check_type(v, path, applications_to_update)
    end
    path
  end
end

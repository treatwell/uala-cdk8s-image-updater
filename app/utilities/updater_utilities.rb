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
      check_type(v, "#{path}/#{k}", applications_to_update)
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
      # puts "APP FOUND: \npath:#{path}\n#{hash.to_yaml}\n\n"
    end
  end

  def iArray(array, path, applications_to_update)
    array.each do |v|
      # puts "ARRAY!" #{v}"
      check_type(v, path, applications_to_update)
    end
    path
  end
end

# CDK8S Image Updater

This tool can be used as a step in a CI pipeline for update docker image references in a cdk8s IaC repository based on an application source repo / branch.

Plugin in action:

![Execution](/example.png)

## Usage

In order to use this tool, some environment variables are required:
* `GIT_IAC_REPO`: This is the most important settings, it contains the IaC repository that you want to update (ONLY GITHUB URL IS ALLOWED AT THIS TIME. ex. `github.com/org/org-iac.git`)
* `GIT_IAC_BRANCH`: By default the tool will use the default branch (master/main). You can set a different branch here.
* `GIT_IAC_FORCE_PR`: By default the tool will create a Pull Request in the case there is a `GIT_SOURCE_TAG`, otherwise a commit will be pushed to the current Iac Repo branch. You can set this to `true` for create a Pull Request also for every commit
* `GIT_IAC_TOKEN`: A github token authorized to access in read/write to the Iac Repo
* `GIT_SOURCE_REPO`: The source repository of the application that want to update the Iac Repo
* `GIT_SOURCE_BRANCH`: The source branch of the application that want to update the Iac Repo
* `GIT_SOURCE_COMMIT_SHA`: The source commit SHA of the application that want to update the Iac Repo
* `GIT_SOURCE_TAG`: The source git tag release of the application that want to update the Iac Repo
* `IAC_DEPLOYER_FILE`: You can generate a deployer file putting here the path of the file you want (ex. `iac_deployer_conf.yaml`). This file can be easly used by [cdk8s-deployer](https://github.com/uala/cdk8s-deployer)

You can run it with docker with:
`docker run -it --env-file .env uala/cdk8s-image-updater`

### Configuration files

This tool requires:
- a configuration file in the root of the IaC Repository where it can find some rules to operate
- a configuration file for every environment defined in the first file

### Applications Conf file
Application Configuration file is a YAML (with ERB support) file stored in the root of your repository and with a syntax like `applications*.yaml`.
Multiple files are supported.
The tree in the configuration MUST match the directory structure of the repo (environments/name_of_environment.

Example `applications.yaml`:
```yaml
environments:
  - develop:
    - name: beAdmin
      git_repo: org/backend-admin
      branch: main
      image: "<%= \"org/backend-admin:#{ENV['GIT_SOURCE_BRANCH'].to_s.gsub(/\/+/, '-')}-#{ENV['GIT_SOURCE_COMMIT_SHA'].to_s[0, 8]}\" %>"
    - name: beMain
      git_repo: org/backend-main
      branch: main
      image: "<%= \"org/backend-main:#{ENV['GIT_SOURCE_BRANCH'].to_s.gsub(/\/+/, '-')}-#{ENV['GIT_SOURCE_COMMIT_SHA'].to_s[0, 8]}\" %>"
```

Example `applications_protected.yaml`:
```yaml
environments:
  - production:
    - name: beAdmin
      git_repo: org/backend-admin
      branch: main
      only_tags: true
      image: "<%= \"org/backend-auth:#{ENV['GIT_SOURCE_TAG'].to_s.gsub(/\/+/, '-')}\" %>"
    - name: beMain
      git_repo: org/backend-main
      branch: main
      only_tags: true
      image: "<%= \"org/backend-auth:#{ENV['GIT_SOURCE_TAG'].to_s.gsub(/\/+/, '-')}\" %>"
```

In the example above, the tool expects that there are 2 environments defined in these paths:
```
applications/environments/develop
applications/environments/production
```

#### Applications Conf file reference

* `git_repo`: It contains the source repository of the application
* `branch`: It contains the source branch of the application
* `only_tags`: if true this configuration will be used if and only if current params contain a valid git tag release
(n.b. it will **NOT** deploy even if branch matches)
* `image`: Docker image used to update the application

It's advised to customize image name. Remember: you can use ERB in YAML config, so you can set this to something like

```yaml
image: <%= "#{ENV['GIT_SOURCE_REPO']}:ENV['GIT_SOURCE_BRANCH']" %>
```


#### Applications Settings file
Every environment defined in the root applications config should contain a different `applications_settings.yaml` file.
This file is a mapping of docker images and namespace for every service that will be deployed in the specific environment.

Example `applications_settings.yaml`:
```yaml
---
beAdmin:
  image: org/backend-admin:main-9ad07451
  namespace: admin-env-dev
beMain:
  image: org/backend-main:main-9ad07451
  namespace: main-env-dev
```

This file should be used by your cdk8s implementation for read the last image to use for every service and the related namespace.


## Development

After checking out the repo, run `bundle install` to install dependencies.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/uala/cdk8s-image-updater

## License

Iac Image Updater is released under the [MIT License](https://opensource.org/licenses/MIT).


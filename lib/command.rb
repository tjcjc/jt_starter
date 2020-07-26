require "thor"
require "mustache"
require "xcodeproj"
require "pathname"

class FileTemplate < Mustache
    @@configs = {}
    def self.config(template_path, project_name, is_pod, is_public, nickname)
        self.template_path = template_path
        @@configs[:project_name] = project_name
        @@configs[:is_pod] = is_pod
        @@configs[:is_public] = is_public
        @@configs[:nickname] = nickname
    end

    def self.render_template(template_file, configs = nil)
        t = FileTemplate.new
        t.template_file = "#{FileTemplate.template_path}/#{template_file}"
        @@configs.each {|k,v| t[k] = v }
        if configs
            configs.each {|k,v| t[k] = v }
        end
        t.render
    end
end

class MyCLI < Thor
    attr_accessor :project_name
    attr_accessor :xcodefile
    attr_accessor :nickname
    attr_accessor :template_path

    include Thor::Shell
    include Thor::Actions

    desc "start", "start a process to init ci files, options: is_public: project is public"
    long_desc <<-LONGDESC
        start a process to init ci files,
        options:
            --is_public option: publish project
    LONGDESC
    option :is_public, type: :boolean
    def start_py
        is_public = options[:is_public]
        unless is_public
            is_public = yes?("Is a public project?")
        end
        
        say("we need your github or gitlab nickname", :green)
        nickname = ask("Nickname: ")

        say("we need your project name", :green)
        project_name = ask("project: ")

        template_path = "#{Pathname.new(File.dirname(__FILE__)).realpath}/template"
        FileTemplate.config(template_path, project_name, !is_p, is_public, nickname)
        create_github_action_file(is_public, nickname, project_name)
    end

    desc "start", "start a process to init ci files, options: is_p: project not pod"
    long_desc <<-LONGDESC
        start a process to init ci files,
        options:
            --is_p option: project not pod
            --is_public option: publish project
    LONGDESC
    option :is_p, type: :boolean
    option :is_public, type: :boolean
    def start
        is_p = options[:is_p]
        unless is_p
            is_p = yes?("Is a project not pod?")
        end
        is_public = options[:is_public]
        unless is_public
            is_public = yes?("Is a public project?")
        end

        say("we need your github or gitlab nickname", :green)
        nickname = ask("Nickname: ")

        template_path = "#{Pathname.new(File.dirname(__FILE__)).realpath}/template"
        project_path = is_p ? Dir.pwd : "#{Dir.pwd}/Example"

        destination_root = Dir.pwd
        Dir.foreach(project_path) do |file|
            if r = file.match(/([\w|\.|\ ]+).xcodeproj$/)
                self.project_name = r[1]
                self.xcodefile = "#{project_path}/#{file}"
            end
        end

        FileTemplate.config(template_path, project_name, !is_p, is_public, nickname)

        create_ci_file(is_public, is_p, nickname, self.project_name)
        create_swiftlint(is_p, xcodefile)
        create_fastfile()
        # Dir.foreach(project_path) do |file|
        #     if r = file.match(/([\w|\.|\ ]+).xcodeproj$/)
        #         project_name = r[1]
        #         xcodefile = "#{path}/#{file}"
        #     end
        # end
        # invoke :create_ci_file, [is_public]
        # invoke :create_swiftlint, [is_p]
        # invoke :create_fastfile
    end

    private
    def create_github_action_file(is_public, nickname, project_name)
        create_file("Gemfile.rb", FileTemplate.render_template("Gemfile_py.rb"))
        say("we need your codecov project key", :green)
        say("get your upload key form this url", :green)
        say("https://codecov.io/gh/#{nickname}/#{project_name}/settings", :yellow)
        while !yes?("finished it?")
        end
        say("Add this key to github project setting as a secret, named [CODECOV_SECRET]", :green)
        say("https://github.com/#{nickname}/#{project_name}/settings/secrets/new", :yellow)
        create_file("README.md", FileTemplate.render_template("README.md"))
        create_file(".pylintrc", FileTemplate.render_template("pylintrc"))
        create_file("environment.yml", FileTemplate.render_template("environment.yml"))
        say("you need create a personal access tokin in github setting, click the link below", :green)
        say("https://github.com/settings/tokens/new", :yellow)
        while !yes?("finished it?")
        end
        say("Add this token to github project setting as a secret, named [REPORT_TOKEN]", :green)
        say("https://github.com/#{nickname}/#{project_name}/settings/secrets/new", :yellow)
        create_file("Dangerfile.rb", FileTemplate.render_template("Dangerfile-py.rb"))
        empty_directory(".github/workflows")
        create_file(".github/workflows/main.yml", FileTemplate.render_template("github/workflows/main.yml"))
    end

    def create_ci_file(is_public, is_project, nickname, project_name)
        create_file("Gemfile", FileTemplate.render_template("Gemfile.rb"))
        if is_public
            create_file("README.md", FileTemplate.render_template("README.md"))
            say("we need your codecov project key", :green)
            say("get your key form this url", :green)
            say("https://codecov.io/gh/#{nickname}/#{project_name}/settings", :yellow)
            codecov_key = ask("your token: ")
            create_file(".travis.yml",
                FileTemplate.render_template(
                    "travis.yml",
                    {codecov_key: codecov_key}))
            say("you need sync the github project in travis", :green)
            say("https://travis-ci.org/account/repositories", :yellow)
            while !yes?("finished it?")
            end
            unless is_project
                generate_token(nickname, project_name, "PUBLISH_KEY")
                create_file(".travis/publish.rb",
                    FileTemplate.render_template(
                        "publish.rb",
                        {codecov_key: codecov_key}))
            end
            generate_token(nickname, project_name, "DANGER_GITHUB_API_TOKEN")
            create_file("Dangerfile", FileTemplate.render_template("Dangerfile.rb"))
        else
            generate_token(nickname, project_name, "DANGER_GITLAB_API_TOKEN", true)
            create_file(".gitlab-ci.yml", FileTemplate.render_template("gitlab-ci.yml"))
            create_file("DangerfileGitlab", FileTemplate.render_template("Dangerfile.rb"))
        end
    end

    def create_swiftlint(is_project, xcodefile)
        create_file(".swiftlint.yml",
            FileTemplate.render_template("swiftlint.yml"))
        say("Do you need create a build script in xcode?", :yellow)
        if yes?("input y for creating: ")
            project = Xcodeproj::Project.open(xcodefile)
            target = project.targets.first
            puts target.build_phases

            unless target.build_phases.find{|p| p.respond_to?("name") && p.name =="swiftlint"}
            phrase = target.new_shell_script_build_phase("swiftlint")
            swift_lint = is_project ? "swiftlint" : 'swiftlint --path "${PROJECT_DIR}/.."'
            puts phrase
            phrase.shell_script = <<-EOF
if which swiftlint >/dev/null; then
#{swift_lint}
else
echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
fi
            EOF
            puts "project save"
            puts project.save
            end
        end
    end

    def create_fastfile
        create_file("fastlane/Fastfile",
            FileTemplate.render_template("Fastfile.rb"))
    end

    def generate_token(nickname, project_name, token_name, is_gitlab = false)
        say("you need create a personal access tokin in github setting, click the link below", :green)
        say("https://github.com/settings/tokens/new", :yellow)

        say("you need create a env variables in travis or gitlab setting with name of #{token_name} and with value of the up token", :green)
        if is_gitlab
            say("https://gitlab.com/#{nickname}/#{project_name}/-/settings/ci_cd", :yellow)
        else
            say("https://travis-ci.org/#{nickname}/#{project_name}/settings", :yellow)
        end
        while !yes?("finished it?")
        end
    end
end

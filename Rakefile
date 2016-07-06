require 'fileutils'

module AT
  class DotfileSetupHandler
    FILES_TO_SKIP = [".","..",".git",".gitignore",".ruby-version"]
    FILES_TO_INCLUDE = [".vim"]

    HOMEBREW_PACKAGES = ["ag","autojump","bash-completion","chruby","ctags","git",
                         "heroku","homebrew/completions/brew-cask-completion","hub","nvm",
                         "pgcli","python","ruby-install","tmux","watch","wemux"]

    BREW_CASK_APPS = ["1password","alfred","atom","bartender","caffeine",
            "daisydisk","dash","divvy","dropbox","firefox","flux","franz","gitx","google-chrome","iterm2",
            "pomotodo","postman","screenhero","sketch","skitch","soulver","spotify"]

    LIBRARIES = [
      { language: "ruby", install_command: "gem install", libs: ["rcodetools","reek"] },
      { language: "python", install_command: "pip install", libs: ["ipython","pygments","pylint","virtualenv"] },
      { language: "node", install_command: "npm install -g", libs: ["eslint_d"] },
    ]

    def initialize(location:, verbose: false)
      @location = location
      @verbose = verbose
      sync_submodules
      setup_symlinks
      install_homebrew_packages
      install_apps
      install_language_versions
      install_libraries
      install_fonts
      setup_vim
      message "All done!"
    end

    private

    def sync_submodules
      message "Syncing submodules..."
      with_log("git submodule sync")
    end

    def setup_symlinks
      message "Setting up symlinks..."
      Dir.foreach('./') do |filename|
        if should_symlink?(filename)
          with_log("rm -rf #{@location}/#{filename}")
          with_log("ln -s #{Dir.pwd}/#{filename} #{@location}/#{filename}")
        end
      end
    end

    def install_homebrew_packages
      if with_log("brew info")
        message "Installing homebrew packages..."
        with_log("brew upgrade #{HOMEBREW_PACKAGES.join(" ")}")
        with_log("brew install #{HOMEBREW_PACKAGES.join(" ")}")
      else
        error "Unable to install dependencies with homebrew, please install #{HOMEBREW_PACKAGES}"
      end
    end

    def install_apps
      if with_log("brew cask help")
        message "Installing apps..."
        with_log("brew cask install #{BREW_CASK_APPS.join(" ")}")
      else
        error "Unable to install apps with brew cask, please install #{BREW_CASK_APPS}"
      end
    end

    def install_language_versions
      message "Installing ruby #{ENV['RB_VERSION']}"
      with_log("ruby-install ruby #{ENV['RB_VERSION']} --no-reinstall") ||
        error("Unable to install ruby")

      node_version = "5.0"
      message "Installing node #{node_version}"
      with_log("nvm install #{node_version}") || error("Unable to install node")
    end

    def install_libraries
      LIBRARIES.each do |lib_def|
        message "Installing #{lib_def[:language]} libraries..."
        lib_def[:libs].each do |l|
          with_log("#{lib_def[:install_command]} #{l}") ||
            error("Unable to install #{l}")
        end
      end
    end

    def install_fonts
      message "Installing powerline fonts"
      with_log("fonts/install.sh")
    end

    def setup_vim
      message "Setting up vim..."
      with_log("cd .vim && rm -rf vundle && git clone http://github.com/gmarik/vundle.git")
      action "Make sure to run :PluginInstall the first time you open up vim!"
    end

    def should_symlink?(filename)
      FILES_TO_INCLUDE.include?(filename) ||
        (filename[0] == '.' && !FILES_TO_SKIP.include?(filename))
    end

    def message(str)
      puts "\e[32m#{str}\e[0m"
    end

    def error(str)
      puts "\e[31m#{str}\e[0m"
    end

    def action(str)
      puts "\e[33m#{str}\e[0m"
    end

    def with_log(command)
      if @verbose
        system("#{command}")
      else
        system("#{command} >> /dev/null 2>&1")
      end
    end
  end
end


task :setup_configs, [:location, :verbose] do |t, args|
  args.with_defaults(location: "$HOME", verbose: false)
  AT::DotfileSetupHandler.new(args)
end

task :default, [:location, :verbose] => :setup_configs
task :quiet,   [:location]           => :setup_configs
task :loud,    [:location]           { |t, args| Rake::Task[:default].invoke(args[:location], true) }

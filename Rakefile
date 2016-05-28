require 'fileutils'

module AT
  class DotfileSetupHandler
    FILES_TO_SKIP = [".","..",".git",".gitignore",".ruby-version"]
    FILES_TO_INCLUDE = [".vim"]

    HOMEBREW_PACKAGES = ["ag","autojump","bash-completion","chruby","ctags","git",
                         "homebrew/completions/brew-cask-completion","hub","macvim","nvm",
                         "pgcli","python","reattach-to-user-namespace","ruby-install","tmux","watch","wemux"]

    BREW_CASK_APPS = ["1password","alfred","atom","bartender","bettertouchtool","caffeine",
            "daisydisk","dash","dropbox","firefox","flux","franz","gitx","google-drive","google-chrome","iterm2",
            "pomotodo","postman","screenhero","sketch","skitch","skype","slack","soulver","spotify","viscosity"]

    LIBRARIES = [
      { language: "ruby", install_command: "gem install", libs: ["rcodetools","reek"] },
      { language: "python", install_command: "pip install", libs: ["pygments","virtualenv","pylint"] },
      { language: "node", install_command: "npm install -g", libs: ["eslint_d"] },
    ]

    attr_accessor :location

    def self.setup_dotfiles
      new("$HOME")
    end

    def initialize(location)
      self.location = location
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
      silent_system("git submodule sync")
    end

    def setup_symlinks
      message "Setting up symlinks..."
      Dir.foreach('./') do |filename|
        if should_symlink?(filename)
          silent_system("rm -rf #{location}/#{filename}")
          silent_system("ln -s #{Dir.pwd}/#{filename} #{location}/#{filename}")
        end
      end
    end

    def install_homebrew_packages
      if silent_system("brew info")
        message "Installing homebrew packages..."
        silent_system("brew upgrade #{HOMEBREW_PACKAGES.join(" ")}")
        silent_system("brew install #{HOMEBREW_PACKAGES.join(" ")}")
      else
        error "Unable to install dependencies with homebrew, please install #{HOMEBREW_PACKAGES}"
      end
    end

    def install_apps
      if silent_system("brew cask help")
        message "Installing apps..."
        silent_system("brew cask install #{BREW_CASK_APPS.join(" ")}")
      else
        error "Unable to install apps with brew cask, please install #{BREW_CASK_APPS}"
      end
    end

    def install_language_versions
      message "Installing ruby #{ENV['RB_VERSION']}"
      silent_system("ruby-install ruby #{ENV['RB_VERSION']} --no-reinstall") ||
        error("Unable to install ruby")

      node_version = "5.0"
      message "Installing node #{node_version}"
      silent_system("nvm install #{node_version}") || error("Unable to install node")
    end

    def install_libraries
      LIBRARIES.each do |lib_def|
        message "Installing #{lib_def[:language]} libraries..."
        lib_def[:libs].each do |l|
          silent_system("#{lib_def[:install_command]} #{l}") ||
            error("Unable to install #{l}")
        end
      end
    end

    def install_fonts
      message "Installing powerline fonts"
      silent_system("fonts/install.sh")
    end

    def setup_vim
      message "Setting up vim..."
      silent_system("cd .vim && rm -rf vundle && git clone http://github.com/gmarik/vundle.git")
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

    def silent_system(command)
      system("#{command} >> /dev/null 2>&1")
    end
  end
end

desc "Symlinks relevant configs"
task :default do
  AT::DotfileSetupHandler.setup_dotfiles
end

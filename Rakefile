require 'fileutils'

module AT
  class DotfileSetupHandler
    FILES_TO_SKIP = [".","..",".git",".gitignore",".ruby-version"]
    FILES_TO_INCLUDE = [".vim"]

    HOMEBREW_PACKAGES = ["autojump","bash-completion","chruby","ctags","dash","git","hub","macvim","nvm",
                    "pgcli","reattach-to-user-namespace","ruby-install","tmux","watch","wemux"]

    APP_DIR = '~/Applications'

    BREW_CASK_APPS = ["1password","alfred","atom","bartender","bettertouchtool","caffeine",
            "daisydisk","dropbox","firefox","flux","gitx","google-drive","google-chrome","iterm2",
            "pomotodo","postman","screenhero","sketch","skitch","skype","slack","soulver","viscosity"]

    GEMS = ["rcodetools","reek"]

    PYTHON_LIBS = ["pygments"]

    NODE_PACKAGES = ["eslint_d"]

    RB_VERSION = "2.2.4"

    attr_accessor :location

    def self.setup_dotfiles
      new("$HOME")
    end

    def initialize(location)
      self.location = location
      setup_symlinks
      install_homebrew_packages
      install_apps
      install_ruby unless ENV['SKIP_RUBY']
      install_gems
      install_python_libraries
      install_node_packages
      setup_vim
      message "All done!"
    end

    private

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
        silent_system("brew cask install --appdir=#{APP_DIR} #{BREW_CASK_APPS.join(" ")}")
      else
        error "Unable to install apps with brew cask, please install #{BREW_CASK_APPS}"
      end
    end

    def install_ruby
      message "Installing ruby #{RB_VERSION}"
      silent_system("ruby-install ruby #{RB_VERSION} --no-reinstall") ||
        error("Unable to install ruby")
    end

    def install_gems
      message "Installing gem dependencies..."
      GEMS.each do |g|
        silent_system("gem install #{g}") ||
          error("Unable to install #{g}")
      end
    end

    def install_python_libraries
      message "Installing python libraries..."
      PYTHON_LIBS.each do |l|
        silent_system("pip install #{l}") ||
          error("Unable to install #{l}")
      end
    end

    def install_node_packages
      message "Installing node packages..."
      NODE_PACKAGES.each do |l|
        silent_system("npm install -g #{l}") ||
          error("Unable to install #{l}")
      end
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
